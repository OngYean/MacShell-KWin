#!/bin/sh
# macshell-session — switch a KDE Plasma session between plasmashell and MacShell, for this login only.
#   status   what is running: plasmashell, MacShell, and the KWin bridge's sanitized check (counts only)
#   start    start MacShell next to plasmashell ("coexist": Plasma keeps notifications, OSD, clipboard history, desktop)
#   stop     stop MacShell (plasmashell is left as it is)
#   replace  stop plasmashell for this login and run MacShell in "replace" mode (it takes over notifications)
#   restore  bring plasmashell back and put MacShell back into coexist mode
# Nothing here is persistent: no unit is enabled, disabled or masked, so logging out and in again always gives the
# normal Plasma session. KWin, Klassy, KDE's lock screen, kded, PowerDevil and the portals are never touched.
set -eu

unit=macshell.service
plasma=plasma-plasmashell.service

have_unit() { systemctl --user cat "$unit" >/dev/null 2>&1; }

start_macshell() {
    if have_unit; then
        if [ "$1" = replace ]; then systemctl --user set-environment MACSHELL_KDE_MODE=replace; else systemctl --user unset-environment MACSHELL_KDE_MODE; fi
        systemctl --user restart "$unit"
    else
        macshell kill >/dev/null 2>&1 || true
        MACSHELL_KDE_MODE="$1" setsid -f macshell >/dev/null 2>&1
    fi
}

stop_macshell() {
    if have_unit; then systemctl --user stop "$unit"; fi
    macshell kill >/dev/null 2>&1 || true
}

# MacShell's notification server keeps its D-Bus name while its process lives: plasmashell only gets it back after
# MacShell has exited, so restore stops MacShell first and starts it again (coexist) once plasmashell is up
wait_for_plasmashell() {
    i=0
    while [ "$i" -lt 30 ]; do
        busctl --user status org.kde.plasmashell >/dev/null 2>&1 && return 0
        sleep 0.5
        i=$((i + 1))
    done
    echo "macshell-session: plasmashell did not come up; check: journalctl --user -u $plasma" >&2
    return 1
}

require_plasma() {
    case "${XDG_CURRENT_DESKTOP:-}" in
        *KDE*) ;;
        *) echo "macshell-session: not a KDE Plasma session (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset})" >&2; exit 2 ;;
    esac
}

case "${1:-status}" in
    status)
        printf 'plasmashell: %s\n' "$(systemctl --user is-active "$plasma" 2>/dev/null || true)"
        if have_unit; then printf 'macshell.service: %s\n' "$(systemctl --user is-active "$unit" 2>/dev/null || true)"; fi
        printf 'macshell instances: %s\n' "$(macshell list 2>/dev/null | grep -c . || true)"
        printf 'MACSHELL_KDE_MODE (user manager): %s\n' "$(systemctl --user show-environment 2>/dev/null | sed -n 's/^MACSHELL_KDE_MODE=//p' | grep . || echo coexist)"
        macshell-kwin-bridge --check --global-menu 2>&1 || true
        ;;
    start) require_plasma; start_macshell coexist ;;
    stop) stop_macshell ;;
    replace)
        require_plasma
        systemctl --user stop "$plasma"
        start_macshell replace
        echo "plasmashell is stopped for this login. Undo: macshell-session restore (or log out and in again)."
        ;;
    restore)
        require_plasma
        stop_macshell
        systemctl --user unset-environment MACSHELL_KDE_MODE 2>/dev/null || true
        systemctl --user start "$plasma"
        wait_for_plasmashell && start_macshell coexist
        ;;
    *)
        echo "usage: macshell-session status|start|stop|replace|restore" >&2
        exit 2
        ;;
esac
