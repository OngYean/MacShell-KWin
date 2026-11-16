#!/bin/sh
# Assemble the Plasma/Shell package that makes MacLock KDE's lock screen:  sh MacLock/kde/build.sh <dir>
# writes <dir>/com.macshell.lock. Used by the flake (packages.macshell-lock) and by nix/test-lock-screen.sh.
#   metadata.json                        from kde/
#   contents/lockscreen/                 kde/lockscreen/: the file KDE loads, and the state all screens share
#   contents/lockscreen/ui/              MacLock's own UI, with kde/ui/ laid over its Quickshell-only files
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
src=$(dirname -- "$here")
[ $# -eq 1 ] || { echo "usage: build.sh <output directory>" >&2; exit 2; }
pkg=$1/com.macshell.lock
ui=$pkg/contents/lockscreen/ui

mkdir -p "$ui"
cp "$here/metadata.json" "$pkg/"
cp "$here"/lockscreen/* "$pkg/contents/lockscreen/"
# shell.qml is the Hyprland entry point (session lock and PAM through Quickshell): not part of the KDE package
for f in "$src"/*.qml "$src"/*.js "$src"/*.qsb "$src"/*.py; do
    [ "$(basename -- "$f")" = shell.qml ] || cp "$f" "$ui/"
done
cp -R "$src/fonts" "$ui/"
# -f: in the Nix build the files copied above are read-only, and these replace four of them
cp -f "$here"/ui/* "$ui/"
