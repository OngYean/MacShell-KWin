#!/usr/bin/env bash
# kwin-smoke.sh — run the KWin bridge and MacShell against a private, headless KWin (virtual output, QPainter
# compositing, software Qt Quick), with its own D-Bus session and Wayland socket: a real session is never touched.
# Needs kwin_wayland, kwrite, macshell, macshell-kwin-bridge and python3 on PATH; CI runs it (.github/workflows):
#   nix shell --inputs-from . nixpkgs#kdePackages.kwin nixpkgs#kdePackages.kate nixpkgs#dbus .#macshell .#macshell-kwin-bridge \
#     --command dbus-run-session -- bash nix/kwin-smoke.sh
#   (outside NixOS add --config-file=<nixpkgs dbus>/share/dbus-1/session.conf to dbus-run-session, as CI does)
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
# stderr logging: the minimize-target check reads a KWin script's console.warn from kwin.log
QT_FORCE_STDERR_LOGGING=1 kwin_wayland --virtual --no-lockscreen --no-global-shortcuts --socket "$sock" --width 1280 --height 800 > "$out/kwin.log" 2>&1 &
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
# contract: every message the real bridge sends matches the protocol (kept in this private run's log dir only)
sleep 6 | timeout 5 macshell-kwin-bridge --global-menu > "$out/bridge-output.jsonl" 2> "$out/bridge-stderr.log"
if v=$(python3 "$here/kwin-bridge/fake-bridge.py" --validate < "$out/bridge-output.jsonl" 2>&1); then note "bridge protocol" "$v"
else fail "bridge protocol" "$(echo "$v" | tail -n 2 | tr '\n' ' ')"; fi

# minimize target (Magic Lamp): the bridge registers a Dock rectangle for KWrite against its anchor surface, and a KWin
# script prints what KWin then reports as KWrite's iconGeometry. The virtual output is at 0,0, so it must be unchanged.
if r=$(timeout 30 python3 - "$out" <<'EOF' 2>&1
import json, os, subprocess, sys, time
out = sys.argv[1]
bridge = subprocess.Popen(["macshell-kwin-bridge"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                          stderr=subprocess.DEVNULL, text=True)
kwrite, screens = None, []
for line in bridge.stdout:
    m = json.loads(line)
    if m["type"] == "windows":
        kwrite = next((w["id"] for w in m["windows"] if "kwrite" in (w["appId"] + w["resourceName"]).lower()), kwrite)
    elif m["type"] == "iconAnchors":
        screens = m["screens"]
    if kwrite and screens:
        break
if not (kwrite and screens):
    sys.exit("KWrite window seen: %s, anchor screens: %d" % (kwrite is not None, len(screens)))
bridge.stdin.write(json.dumps({"cmd": "iconGeometry", "id": kwrite, "screen": screens[0],
                               "x": 600, "y": 700, "width": 48, "height": 48}) + "\n")
bridge.stdin.flush()
time.sleep(1)
script = os.path.join(out, "icon-geometry.js")
with open(script, "w") as f:
    f.write("for (const w of workspace.windowList()) if (w.normalWindow && String(w.resourceClass).toLowerCase().includes('kwrite')) {"
            " const g = w.iconGeometry; console.warn('macshell-icon-geometry ' + Math.round(g.x) + ',' + Math.round(g.y) + ' '"
            " + Math.round(g.width) + 'x' + Math.round(g.height)); }\n")
dbus = ["dbus-send", "--session", "--print-reply=literal", "--dest=org.kde.KWin"]
loaded = subprocess.run(dbus + ["/Scripting", "org.kde.kwin.Scripting.loadScript", "string:" + script,
                                "string:macshell-smoke-icon"], capture_output=True, text=True, check=True)
subprocess.run(dbus + ["/Scripting/Script" + loaded.stdout.split()[-1], "org.kde.kwin.Script.run"], check=True)
time.sleep(1)
bridge.stdin.close()
bridge.wait(5)
print("%s (anchors on %d screen(s))" % (screens[0], len(screens)))
EOF
); then
    if grep -q 'macshell-icon-geometry 600,700 48x48' "$out/kwin.log"; then
        note "minimize target" "KWin reports KWrite's iconGeometry as the Dock rectangle on $r"
    else
        fail "minimize target" "KWin's iconGeometry for KWrite: $(grep -m 1 -o 'macshell-icon-geometry.*' "$out/kwin.log" || echo 'not printed')"
    fi
else
    fail "minimize target" "$(echo "$r" | tail -n 2 | tr '\n' ' ')"
fi

# MacShell itself, once with the real bridge and once with the fake one (exercises the global-menu rendering)
run_shell() { # name, extra environment...
    name=$1
    shift
    env "$@" timeout 30 macshell --verbose --no-color > "$out/macshell-$name.log" 2>&1
    if ! grep -q 'Configuration Loaded' "$out/macshell-$name.log"; then
        fail "macshell ($name)" "configuration did not load: $(grep -m 3 -E 'ERROR|error|qml:' "$out/macshell-$name.log" | tr '\n' ' ')"
    else
        note "macshell ($name)" "configuration loaded"
    fi
    # QML diagnostics: Quickshell logs engine warnings as "@/<file>.qml[line:col]: …" (core/generation.cpp
    # onEngineWarnings); Qt's own messages use "<url>.qml:line"; both are listed
    grep -E '\.qml(\[[0-9]+:[0-9]+\]|:[0-9]+)' "$out/macshell-$name.log" | sed -E 's#^.* (@/?|[^ ]*qs:@/qs/|[^ ]*share/macshell/|[^ ]*/MacShell/)##' | sort -u > "$out/qml-$name.txt"
    n=$(wc -l < "$out/qml-$name.txt")
    note "macshell ($name) QML diagnostics" "$n distinct lines"
    head -n 8 "$out/qml-$name.txt" | cut -c1-600 | while IFS= read -r line; do note "QML ($name)" "$line"; done
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
