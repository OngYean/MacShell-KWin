#!/bin/sh
# Brightness backend for MacBar.qml.
#   brightness.sh get       -> prints "<mode> <percent>"   (mode = kde | bl | ddc | none)
#   brightness.sh set <1-100>
# In a KDE session PowerDevil owns screen brightness (backlight and DDC monitors) and restores its own value, so it is
# asked over D-Bus (org.kde.ScreenBrightness) instead of writing the backlight behind its back.
# Laptop panels use brightnessctl (sysfs backlight). If there is no backlight device (desktop PCs, external
# monitors) it falls back to ddcutil (DDC/CI, VCP feature 0x10) and sets every display ddcutil can see.
# ddcutil needs the i2c-dev kernel module and access to /dev/i2c-* (user in the "i2c" group, or a udev rule).

cache="${XDG_RUNTIME_DIR:-/tmp}/macshell-ddc-displays"

bl_line() { command -v brightnessctl >/dev/null 2>&1 && brightnessctl -m -c backlight 2>/dev/null | head -n1; }
has_bl() { [ -n "$(bl_line)" ]; }
has_ddc() { command -v ddcutil >/dev/null 2>&1; }

kde_call() { dbus-send --session --print-reply --dest=org.kde.ScreenBrightness "$@" 2>/dev/null; }
# PowerDevil's display names (only [A-Za-z0-9_]: they become object paths); none outside KDE or without PowerDevil
kde_displays() {
    case ":${XDG_CURRENT_DESKTOP:-}:" in *:KDE:*) ;; *) return ;; esac
    command -v dbus-send >/dev/null 2>&1 || return
    kde_call /org/kde/ScreenBrightness org.freedesktop.DBus.Properties.Get string:org.kde.ScreenBrightness string:DisplaysDBusNames \
        | sed -n 's/^ *string "\([A-Za-z0-9_]*\)"$/\1/p'
}
kde_prop() {
    kde_call "/org/kde/ScreenBrightness/$1" org.freedesktop.DBus.Properties.Get string:org.kde.ScreenBrightness.Display "string:$2" \
        | awk '$1 == "variant" && $2 == "int32" { print $3 }'
}

ddc_displays() {
    if [ -s "$cache" ]; then cat "$cache"; return; fi
    d=$(ddcutil detect --brief 2>/dev/null | sed -n 's/^Display \([0-9][0-9]*\).*/\1/p')
    [ -n "$d" ] && printf '%s\n' "$d" | tee "$cache"
}

case "$1" in
get)
    n=$(kde_displays | head -n1)
    if [ -n "$n" ]; then
        b=$(kde_prop "$n" Brightness); m=$(kde_prop "$n" MaxBrightness)
        if [ -n "$b" ] && [ "${m:-0}" -gt 0 ] 2>/dev/null; then echo "kde $((b * 100 / m))"; exit 0; fi
    fi
    l=$(bl_line)
    if [ -n "$l" ]; then
        p=$(printf '%s' "$l" | cut -d, -f4 | tr -d '%')
        echo "bl ${p:-50}"
    elif has_ddc; then
        n=$(ddc_displays | head -n1)
        [ -z "$n" ] && { echo "none 50"; exit 0; }
        # terse output: "VCP 10 C <current> <max>"
        r=$(ddcutil --display "$n" getvcp 10 -t --sleep-multiplier .1 2>/dev/null | awk '$1=="VCP" && $3=="C" && $5>0 { printf "%d", $4*100/$5 }')
        [ -z "$r" ] && { rm -f "$cache"; echo "none 50"; exit 0; }
        echo "ddc $r"
    else
        echo "none 50"
    fi
    ;;
set)
    v=$(printf '%s' "$2" | tr -dc '0-9'); [ -z "$v" ] && exit 1
    [ "$v" -lt 1 ] && v=1; [ "$v" -gt 100 ] && v=100
    ds=$(kde_displays)
    if [ -n "$ds" ]; then
        # every display PowerDevil controls, like the DDC branch; flag 0x1 = no KDE OSD (MacShell shows its own)
        for n in $ds; do
            m=$(kde_prop "$n" MaxBrightness)
            [ "${m:-0}" -gt 0 ] 2>/dev/null || continue
            kde_call "/org/kde/ScreenBrightness/$n" org.kde.ScreenBrightness.Display.SetBrightness "int32:$((v * m / 100))" uint32:1 >/dev/null
        done
    elif has_bl; then
        brightnessctl -q -c backlight set "${v}%"
    elif has_ddc; then
        for n in $(ddc_displays); do
            ddcutil --display "$n" setvcp 10 "$v" --noverify --sleep-multiplier .1 >/dev/null 2>&1 &
        done
        wait
    fi
    ;;
*) echo "usage: $0 get | set <1-100>" >&2; exit 2 ;;
esac
