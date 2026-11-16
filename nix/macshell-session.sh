#!/bin/sh
# macshell-session — run MacShell in a KDE Plasma session, in place of plasmashell (the default) or next to it.
#   status   what is running: plasmashell, MacShell, and the KWin bridge's sanitized check (counts only)
#   start    stop plasmashell for this login and run MacShell in its place ("replace": MacShell draws the wallpaper and
#            takes over notifications). `replace` does the same.
#   coexist  run MacShell next to plasmashell, starting plasmashell again if it was stopped (Plasma keeps its
#            notifications, pop-ups, clipboard history and desktop). `restore` does the same.
#   stop     stop MacShell, and bring plasmashell back so the session is never left without a shell
# Nothing above is persistent: no unit is enabled, disabled or masked. What the next login does is up to programs.macshell
# (Home Manager): with autostart and mode = "replace" plasmashell is skipped at login, otherwise it starts as usual.
#   autostart replace|coexist|off   the same choice for installs outside Nix (install.sh, the Arch package). It is the
#            one persistent command: it enables or disables macshell.service for Plasma logins, and for "replace" writes
#            the two files that make plasmashell skip itself at login. plasmashell is never masked or removed.
# KWin, Klassy, KDE's lock screen, kded, PowerDevil and the portals are never touched.
set -eu

unit="macshell.service"
plasma="plasma-plasmashell.service"
# macshell and the bridge are installed next to this script, which need not be on PATH (~/.local/bin)
PATH="$PATH:${0%/*}"
export PATH

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

# Call with MacShell already stopped: its notification server keeps its D-Bus name while its process lives, and
# plasmashell only gets the name if MacShell is gone. MACSHELL_KDE_MODE=replace in the user manager also keeps
# plasmashell's unit from starting (programs.macshell's drop-in), so it is unset first.
bring_plasmashell_back() {
    systemctl --user unset-environment MACSHELL_KDE_MODE 2>/dev/null || true
    systemctl --user start "$plasma"
    wait_for_plasmashell
}

in_plasma() { case "${XDG_CURRENT_DESKTOP:-}" in *KDE*) return 0 ;; *) return 1 ;; esac; }

require_plasma() {
    in_plasma || { echo "macshell-session: not a KDE Plasma session (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset})" >&2; exit 2; }
}

case "${1:-status}" in
    status)
        printf 'plasmashell: %s\n' "$(systemctl --user is-active "$plasma" 2>/dev/null || true)"
        if have_unit; then printf 'macshell.service: %s\n' "$(systemctl --user is-active "$unit" 2>/dev/null || true)"; fi
        printf 'macshell instances: %s\n' "$(macshell list --json 2>/dev/null | grep -c '"pid"' || true)"
        printf 'MACSHELL_KDE_MODE (user manager): %s\n' "$(systemctl --user show-environment 2>/dev/null | sed -n 's/^MACSHELL_KDE_MODE=//p' | grep . || echo coexist)"
        macshell-kwin-bridge --check --global-menu 2>&1 || true
        ;;
    start | replace)
        require_plasma
        systemctl --user stop "$plasma"
        start_macshell replace
        echo "plasmashell is stopped for this login. Back to it: macshell-session coexist (MacShell next to it) or stop."
        ;;
    coexist | restore)
        require_plasma
        stop_macshell
        bring_plasmashell_back && start_macshell coexist
        ;;
    stop)
        stop_macshell
        if in_plasma; then bring_plasmashell_back; fi
        ;;
    autostart)
        conf="${XDG_CONFIG_HOME:-$HOME/.config}"
        # what programs.macshell writes with mode = "replace": plasmashell's unit skips itself while the variable is set,
        # and the variable is in the user manager's environment from login on
        dropin="$conf/systemd/user/$plasma.d/macshell.conf"
        envfile="$conf/environment.d/macshell.conf"
        if [ -L "$conf/systemd/user/$unit" ]; then
            echo "macshell-session: $unit is managed by Home Manager; set programs.macshell.autostart and .mode instead" >&2
            exit 2
        fi
        case "${2:-}" in
            replace)
                mkdir -p "${dropin%/*}" "${envfile%/*}"
                printf '[Unit]\nConditionEnvironment=!MACSHELL_KDE_MODE=replace\n' > "$dropin"
                printf 'MACSHELL_KDE_MODE=replace\n' > "$envfile"
                systemctl --user daemon-reload
                systemctl --user enable "$unit"
                echo "From the next Plasma login MacShell starts in place of plasmashell. For this login: macshell-session start"
                ;;
            coexist)
                rm -f "$dropin" "$envfile"
                systemctl --user daemon-reload
                systemctl --user enable "$unit"
                echo "From the next Plasma login MacShell starts next to plasmashell. For this login: macshell-session coexist"
                ;;
            off)
                rm -f "$dropin" "$envfile"
                systemctl --user disable "$unit" || true
                systemctl --user daemon-reload
                echo "Plasma logins start plasmashell only."
                ;;
            *)
                echo "usage: macshell-session autostart replace|coexist|off" >&2
                exit 2
                ;;
        esac
        ;;
    *)
        echo "usage: macshell-session status|start|coexist|stop|autostart   (replace = start, restore = coexist)" >&2
        exit 2
        ;;
esac
