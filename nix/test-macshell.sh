#!/bin/sh
# test-macshell.sh — checks nix/macshell.sh against a stand-in qs that only logs.
# The launcher must pass its arguments on and turn the "KDE's text rendering" setting into QML_DISABLE_DISTANCEFIELD.
#   sh nix/test-macshell.sh            (no Quickshell or Nix needed)
# shellcheck disable=SC2016  # the stub body is written literally: it expands when the stub runs
set -eu
here=$(cd "$(dirname "$0")" && pwd)
script="$here/macshell.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/home/.config/macdock"
printf '#!/bin/sh\necho "qs $* [df=${QML_DISABLE_DISTANCEFIELD-unset}]"\n' > "$work/bin/qs"
chmod +x "$work/bin/qs"
settings="$work/home/.config/macdock/settings.json"

run() { PATH="$work/bin" HOME="$work/home" MACSHELL_CONFIG=/cfg /bin/sh "$script" "$@"; }
check() { # name, expected, actual
    [ "$2" = "$3" ] || { printf 'FAIL: %s\nwant: %s\ngot:  %s\n' "$1" "$2" "$3"; exit 1; }
    echo "ok: $1"
}

check "no settings file: Qt's own text rendering" "qs -p /cfg [df=unset]" "$(run)"
printf '{\n  "iconSize": 52,\n  "nativeText": false\n}\n' > "$settings"
check "setting off" "qs -p /cfg [df=unset]" "$(run)"
printf '{\n  "iconSize": 52,\n  "nativeText": true,\n  "accent": "#0a84ff"\n}\n' > "$settings"
check "setting on: the system's rasterizer" "qs -p /cfg [df=1]" "$(run)"
check "an empty variable forces Qt's rendering" "qs -p /cfg [df=unset]" "$(QML_DISABLE_DISTANCEFIELD='' run)"
check "ipc is passed through untouched" "qs ipc -p /cfg call spotlight toggle [df=unset]" "$(run ipc call spotlight toggle)"
