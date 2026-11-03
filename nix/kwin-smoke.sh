#!/usr/bin/env bash
# kwin-smoke.sh — run the KWin bridge and MacShell against a private, headless KWin (virtual output, QPainter
# compositing, software Qt Quick), with its own D-Bus session and Wayland socket: a real session is never touched.
# Needs kwin_wayland, kwrite, macshell, macshell-kwin-bridge and python3 on PATH; CI runs it (.github/workflows):
#   nix shell --inputs-from . nixpkgs#kdePackages.kwin nixpkgs#kdePackages.kate nixpkgs#dbus .#macshell .#macshell-kwin-bridge \
#     --command dbus-run-session -- bash nix/kwin-smoke.sh
# Results are printed as GitHub annotations (::notice / ::error) and the exit status is the number of failed checks.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
out=${SMOKE_OUT:-$PWD/smoke}
mkdir -p "$out"
fails=0
note() { echo "::notice title=$1::$2"; }
fail() { echo "::error title=$1::$2"; fails=$((fails + 1)); }

XDG_RUNTIME_DIR=$(mktemp -d)
chmod 700 "$XDG_RUNTIME_DIR"
export XDG_RUNTIME_DIR KWIN_COMPOSE=Q QT_QUICK_BACKEND=software XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=wayland
sock=wayland-macshell-smoke
kwin_wayland --virtual --no-lockscreen --no-global-shortcuts --socket "$sock" --width 1280 --height 800 > "$out/kwin.log" 2>&1 &
kwin=$!
trap 'kill $kwin 2>/dev/null; kill $(jobs -p) 2>/dev/null' EXIT
for _ in $(seq 100); do [ -S "$XDG_RUNTIME_DIR/$sock" ] && break; sleep 0.1; done
if [ ! -S "$XDG_RUNTIME_DIR/$sock" ]; then
    fail kwin "headless KWin did not start: $(tail -n 3 "$out/kwin.log" | tr '\n' ' ')"
    exit "$fails"
fi
note kwin "headless KWin up: $(kwin_wayland --version 2>/dev/null)"
export WAYLAND_DISPLAY=$sock QT_QPA_PLATFORM=wayland

# the bridge against KWin, with no window and then with KWrite open (counts only)
sleep 2
c=$(macshell-kwin-bridge --check 2>&1 | tail -n 1)
case "$c" in *window_management=available*) note "bridge --check (no windows)" "$c" ;; *) fail "bridge --check" "$c" ;; esac
kwrite > "$out/kwrite.log" 2>&1 &
sleep 6
c=$(macshell-kwin-bridge --check --global-menu 2>&1 | tr '\n' ' ')
case "$c" in *windows=[1-9]*active_window_present=true*) note "bridge --check (KWrite open)" "$c" ;; *) fail "bridge --check with KWrite" "$c" ;; esac

# MacShell itself, once with the real bridge and once with the fake one (exercises the global-menu rendering)
run_shell() { # name, extra environment...
    name=$1
    shift
    env "$@" timeout 30 macshell --verbose > "$out/macshell-$name.log" 2>&1
    if ! grep -q 'Configuration Loaded' "$out/macshell-$name.log"; then
        fail "macshell ($name)" "configuration did not load: $(grep -m 3 -E 'ERROR|error|qml:' "$out/macshell-$name.log" | tr '\n' ' ')"
    else
        note "macshell ($name)" "configuration loaded"
    fi
    # QML diagnostics that point into MacShell's own files
    grep -E 'MacShell/[A-Za-z/]+\.qml:[0-9]+' "$out/macshell-$name.log" | sed -E 's/^.*(MacShell\/)/\1/' | sort -u > "$out/qml-$name.txt"
    n=$(wc -l < "$out/qml-$name.txt")
    note "macshell ($name) QML diagnostics" "$n distinct lines (first: $(head -n 3 "$out/qml-$name.txt" | tr '\n' ' '))"
    if grep -q -E 'backends/compositor/|ReferenceError|TypeError|is not a type|is not installed' "$out/qml-$name.txt"; then
        fail "macshell ($name)" "$(grep -m 3 -E 'backends/compositor/|ReferenceError|TypeError|is not a type|is not installed' "$out/qml-$name.txt" | tr '\n' ' ')"
    fi
    if grep -q 'HYPRLAND_INSTANCE_SIGNATURE is unset' "$out/macshell-$name.log"; then
        fail "macshell ($name)" "the Hyprland IPC client started under KWin (an ungated Hyprland use)"
    fi
}
run_shell real MACSHELL_COMPOSITOR=kwin
run_shell fake MACSHELL_COMPOSITOR=kwin MACSHELL_KWIN_BRIDGE="$here/kwin-bridge/fake-bridge.py"
exit "$fails"
