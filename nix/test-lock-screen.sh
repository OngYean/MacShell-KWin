#!/bin/sh
# Load checks for MacLock without a Plasma or Hyprland session (run from the repository root):
#   kde         the package KDE's lock screen loads (MacLock/kde/build.sh), with its password flow walked against
#               a stand-in for KDE's authenticator
#   quickshell  MacLock's UI with its Quickshell-side files, against stand-ins for Quickshell's modules
# Both run in Qt's `qml` tool on the offscreen platform; the stand-ins are in nix/lock-screen-test/. This shows the
# QML files fit together and the state logic holds, not that the screen locks, unlocks or draws correctly.
#   QML_RUNNER   the tool to run (default: qml), called as: $QML_RUNNER [-I dir]... file.qml
#   QML_IMPORTS  extra QML import directories, colon-separated (nixpkgs splits Qt: QtQuick is not found by itself)
set -eu

runner=${QML_RUNNER:-qml}
tests=nix/lock-screen-test
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

sh MacLock/kde/build.sh "$tmp/kde"
cp "$tests/kde.qml" "$tmp/kde/"
mkdir -p "$tmp/quickshell"
cp -R MacLock "$tmp/quickshell/MacLock"
cp "$tests/quickshell.qml" "$tmp/quickshell/"

fail=0
for side in kde quickshell; do
    case $side in kde) stubs=$tests/kde-stubs ;; *) stubs=$tests/qs-stubs ;; esac
    set -- -I "$stubs"
    old_ifs=$IFS; IFS=:
    for dir in ${QML_IMPORTS:-}; do [ -n "$dir" ] && set -- "$@" -I "$dir"; done
    IFS=$old_ifs
    code=0
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$runner" "$@" "$tmp/$side/$side.qml" > "$tmp/$side.log" 2>&1 || code=$?
    # a script error in a binding is only a warning to QML: treat it as a failure too
    errors=$(grep -c -E 'ReferenceError|TypeError|is not a type|is not defined|Cannot assign|Unable to assign' "$tmp/$side.log" || true)
    if [ "$code" = 0 ] && [ "$errors" = 0 ] && grep -q "lock-screen-test: PASS ($side)" "$tmp/$side.log"; then
        echo "lock-screen-test: $side ok"
    else
        echo "lock-screen-test: $side FAILED (exit $code, $errors script errors)"
        sed "s|$tmp/||g" "$tmp/$side.log"
        fail=1
    fi
done
exit "$fail"
