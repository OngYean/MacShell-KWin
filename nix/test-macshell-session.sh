#!/bin/sh
# test-macshell-session.sh — checks the order of what macshell-session does, with stand-in commands that only log.
# The order matters: plasmashell must be stopped before MacShell claims notifications (replace), and MacShell must be
# gone before plasmashell starts again (restore), or plasmashell comes back without its notification name.
#   sh nix/test-macshell-session.sh            (no Plasma, systemd or Nix needed)
# shellcheck disable=SC2016  # the stub bodies are written literally: they expand when the stubs run
set -eu
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
log="$work/log"

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

HAVE_UNIT=1 run 0 replace
expect "replace (systemd unit): plasmashell stops before MacShell restarts in replace mode" "systemctl --user stop plasma-plasmashell.service
systemctl --user cat macshell.service
systemctl --user set-environment MACSHELL_KDE_MODE=replace
systemctl --user restart macshell.service"

HAVE_UNIT=1 run 0 restore
expect "restore (systemd unit): MacShell stops, plasmashell starts and is up, then MacShell restarts in coexist" "systemctl --user cat macshell.service
systemctl --user stop macshell.service
macshell kill MACSHELL_KDE_MODE=
systemctl --user unset-environment MACSHELL_KDE_MODE
systemctl --user start plasma-plasmashell.service
busctl --user status org.kde.plasmashell
systemctl --user cat macshell.service
systemctl --user unset-environment MACSHELL_KDE_MODE
systemctl --user restart macshell.service"

HAVE_UNIT=0 run 0 replace
expect "replace (no unit): plasmashell stops, then a detached MacShell starts in replace mode" "systemctl --user stop plasma-plasmashell.service
systemctl --user cat macshell.service
macshell kill MACSHELL_KDE_MODE=
macshell  MACSHELL_KDE_MODE=replace"

HAVE_UNIT=0 PLASMA_COMES_UP=0 run 1 restore
expect "restore: plasmashell never appears, so MacShell is not restarted" "systemctl --user cat macshell.service
macshell kill MACSHELL_KDE_MODE=
systemctl --user unset-environment MACSHELL_KDE_MODE
systemctl --user start plasma-plasmashell.service
$(i=0; while [ "$i" -lt 30 ]; do echo "busctl --user status org.kde.plasmashell"; i=$((i + 1)); done)"

DESKTOP=Hyprland run 2 replace
expect "replace outside Plasma: refused before touching anything" ""

run 2 bogus
expect "unknown command: usage, nothing run" ""
