#!/bin/sh
# test-brightness.sh — checks MacShell/assets/brightness.sh against stand-in dbus-send / brightnessctl that only log.
# In KDE, PowerDevil (org.kde.ScreenBrightness) must be used and the backlight left alone; elsewhere nothing changes.
#   sh nix/test-brightness.sh            (no Plasma, PowerDevil or Nix needed)
# shellcheck disable=SC2016  # the stub bodies are written literally: they expand when the stubs run
set -eu
here=$(cd "$(dirname "$0")" && pwd)
script="$here/../MacShell/assets/brightness.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
log="$work/log"

stub() { # name, body
    printf '#!/bin/sh\n%s\n' "$2" > "$work/bin/$1"
    chmod +x "$work/bin/$1"
}
# replies in dbus-send --print-reply's format: display0 is 9600 of 19200, display1 is 40 of 100
stub dbus-send '[ -e "$LOG.nopd" ] && exit 1
case "$*" in
  *SetBrightness*) echo "dbus-send $*" >> "$LOG" ;;
  *DisplaysDBusNames*) printf "method return\n   variant       array [\n         string \"display0\"\n         string \"display1\"\n      ]\n" ;;
  */display0*MaxBrightness*) printf "method return\n   variant       int32 19200\n" ;;
  */display0*Brightness*) printf "method return\n   variant       int32 9600\n" ;;
  */display1*MaxBrightness*) printf "method return\n   variant       int32 100\n" ;;
  */display1*Brightness*) printf "method return\n   variant       int32 40\n" ;;
esac'
stub brightnessctl 'echo "brightnessctl $*" >> "$LOG"; case "$*" in *-m*) echo "amdgpu_bl1,backlight,60,30%,200" ;; esac'

run() { # desktop, arguments; prints the script's output
    : > "$log"
    PATH="$work/bin:$PATH" LOG="$log" XDG_CURRENT_DESKTOP="$1" sh "$script" "$2" ${3:+"$3"}
}
check() { # name, expected, actual
    [ "$2" = "$3" ] || { printf 'FAIL: %s\nwant: %s\ngot:  %s\nlog:\n' "$1" "$2" "$3"; cat "$log"; exit 1; }
    echo "ok: $1"
}

check "KDE: get reads PowerDevil's first display" "kde 50" "$(run KDE get)"
check "KDE: get leaves the backlight alone" "" "$(cat "$log")"

run KDE set 30 > /dev/null
check "KDE: set scales to every display's maximum, without KDE's OSD" "dbus-send --session --print-reply --dest=org.kde.ScreenBrightness /org/kde/ScreenBrightness/display0 org.kde.ScreenBrightness.Display.SetBrightness int32:5760 uint32:1
dbus-send --session --print-reply --dest=org.kde.ScreenBrightness /org/kde/ScreenBrightness/display1 org.kde.ScreenBrightness.Display.SetBrightness int32:30 uint32:1" "$(cat "$log")"

touch "$log.nopd"
check "KDE without PowerDevil: get falls back to the backlight" "bl 30" "$(run KDE get)"
rm "$log.nopd"

check "Hyprland: get uses the backlight" "bl 30" "$(run Hyprland get)"
run Hyprland set 30 > /dev/null
check "Hyprland: set never asks PowerDevil" "brightnessctl -m -c backlight
brightnessctl -q -c backlight set 30%" "$(cat "$log")"
