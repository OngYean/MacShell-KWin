#!/bin/sh
# test-macshell-session.sh — checks the order of what macshell-session does, with stand-in commands that only log.
# The order matters: plasmashell must be stopped before MacShell claims notifications (start / replace), and MacShell
# must be gone before plasmashell starts again (coexist / restore / stop), or plasmashell comes back without its
# notification name.
#   sh nix/test-macshell-session.sh            (no Plasma, systemd or Nix needed)
# shellcheck disable=SC2016  # the stub bodies are written literally: they expand when the stubs run
set -eu
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin" "$work/home"
log="$work/log"
# autostart writes under ~/.config: never the real one
HOME="$work/home"
unset XDG_CONFIG_HOME
export HOME

stub() { # name, body
    printf '#!/bin/sh\n%s\n' "$2" > "$work/bin/$1"
    chmod +x "$work/bin/$1"
}
stub systemctl 'echo "systemctl $*" >> "$LOG"; if [ "$2" = cat ]; then [ "${HAVE_UNIT:-1}" = 1 ]; fi'
stub busctl 'echo "busctl $*" >> "$LOG"; [ "${PLASMA_COMES_UP:-1}" = 1 ]'
stub macshell 'echo "macshell $* MACSHELL_KDE_MODE=${MACSHELL_KDE_MODE:-}" >> "$LOG"'
stub macshell-kwin-bridge 'echo "bridge $*" >> "$LOG"'
stub setsid 'shift; "$@"'
stub sleep ':'

run() { # expected exit, then arguments for macshell-session
    want=$1
    shift
    : > "$log"
    set +e
    PATH="$work/bin:$PATH" LOG="$log" XDG_CURRENT_DESKTOP="${DESKTOP:-KDE}" sh "$here/macshell-session.sh" "$@" > /dev/null 2>&1
    got=$?
    set -e
    [ "$got" = "$want" ] || { echo "FAIL: macshell-session $* exited $got, expected $want"; cat "$log"; exit 1; }
}

expect() { # name, expected log (one call per line; "" = nothing was called)
    if [ -z "$2" ]; then : > "$work/want"; else printf '%s\n' "$2" > "$work/want"; fi
    diff -u "$work/want" "$log" > "$work/diff" || { echo "FAIL: $1"; cat "$work/diff"; exit 1; }
    echo "ok: $1"
}

HAVE_UNIT=1 run 0 start
expect "start (systemd unit, the default: replace): plasmashell stops before MacShell restarts in replace mode" "systemctl --user stop plasma-plasmashell.service
systemctl --user cat macshell.service
systemctl --user set-environment MACSHELL_KDE_MODE=replace
systemctl --user restart macshell.service"

HAVE_UNIT=0 run 0 replace
expect "replace = start (no unit): plasmashell stops, then a detached MacShell starts in replace mode" "systemctl --user stop plasma-plasmashell.service
systemctl --user cat macshell.service
macshell kill MACSHELL_KDE_MODE=
macshell  MACSHELL_KDE_MODE=replace"

HAVE_UNIT=1 run 0 coexist
expect "coexist (systemd unit): MacShell stops, plasmashell starts and is up, then MacShell restarts in coexist" "systemctl --user cat macshell.service
systemctl --user stop macshell.service
macshell kill MACSHELL_KDE_MODE=
systemctl --user unset-environment MACSHELL_KDE_MODE
systemctl --user start plasma-plasmashell.service
busctl --user status org.kde.plasmashell
systemctl --user cat macshell.service
systemctl --user unset-environment MACSHELL_KDE_MODE
systemctl --user restart macshell.service"

HAVE_UNIT=0 PLASMA_COMES_UP=0 run 1 restore
expect "restore = coexist: plasmashell never appears, so MacShell is not restarted" "systemctl --user cat macshell.service
macshell kill MACSHELL_KDE_MODE=
systemctl --user unset-environment MACSHELL_KDE_MODE
systemctl --user start plasma-plasmashell.service
$(i=0; while [ "$i" -lt 30 ]; do echo "busctl --user status org.kde.plasmashell"; i=$((i + 1)); done)"

# (sh keeps assignments made in front of a function call, so set again what an earlier test changed)
HAVE_UNIT=1 PLASMA_COMES_UP=1 run 0 stop
expect "stop (Plasma): MacShell stops, then plasmashell comes back (the session never stays without a shell)" "systemctl --user cat macshell.service
systemctl --user stop macshell.service
macshell kill MACSHELL_KDE_MODE=
systemctl --user unset-environment MACSHELL_KDE_MODE
systemctl --user start plasma-plasmashell.service
busctl --user status org.kde.plasmashell"

DESKTOP=Hyprland HAVE_UNIT=1 run 0 stop
expect "stop outside Plasma: only MacShell stops, plasmashell is not started" "systemctl --user cat macshell.service
systemctl --user stop macshell.service
macshell kill MACSHELL_KDE_MODE="

DESKTOP=Hyprland run 2 start
expect "start outside Plasma: refused before touching anything" ""

run 2 bogus
expect "unknown command: usage, nothing run" ""

# ── autostart: the one persistent command (installs outside Nix) ──
dropin="$HOME/.config/systemd/user/plasma-plasmashell.service.d/macshell.conf"
envfile="$HOME/.config/environment.d/macshell.conf"
files() { # name, expected drop-in and environment file contents ("" = the file must not exist)
    for pair in "$dropin|$2" "$envfile|$3"; do
        f=${pair%%|*}
        want=${pair#*|}
        if [ -z "$want" ]; then [ ! -e "$f" ] || { echo "FAIL: $1: $f exists"; exit 1; }
        else [ "$(cat "$f" 2>/dev/null)" = "$want" ] || { echo "FAIL: $1: $f is not '$want'"; exit 1; }; fi
    done
    echo "ok: $1 (files)"
}

run 0 autostart replace
expect "autostart replace: the unit is enabled after the files are in place" "systemctl --user daemon-reload
systemctl --user enable macshell.service"
files "autostart replace: plasmashell skips itself at login" "[Unit]
ConditionEnvironment=!MACSHELL_KDE_MODE=replace" "MACSHELL_KDE_MODE=replace"

run 0 autostart coexist
expect "autostart coexist: the unit stays enabled" "systemctl --user daemon-reload
systemctl --user enable macshell.service"
files "autostart coexist: nothing keeps plasmashell from starting" "" ""

run 0 autostart replace
run 0 autostart off
expect "autostart off: the unit is disabled" "systemctl --user disable macshell.service
systemctl --user daemon-reload"
files "autostart off: plasmashell starts at login again" "" ""

run 2 autostart
expect "autostart without a mode: usage, nothing run" ""

mkdir -p "$HOME/.config/systemd/user"
ln -s /nonexistent/macshell.service "$HOME/.config/systemd/user/macshell.service"
run 2 autostart replace
expect "autostart with Home Manager's unit: refused, nothing run" ""
files "autostart with Home Manager's unit: nothing written" "" ""
