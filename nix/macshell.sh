#!/bin/sh
# macshell — run MacShell (Quickshell) from its installed configuration.
#   macshell                              start the shell (the compositor backend is detected: KWin or Hyprland)
#   macshell ipc call spotlight toggle    talk to the running shell (also: log, list, kill); use this in KDE shortcuts
# MACSHELL_CONFIG is set by the Nix wrapper to the configuration in the store.
cfg="${MACSHELL_CONFIG:?MACSHELL_CONFIG is not set (run the packaged macshell)}"
case "${1:-}" in
    ipc | log | list | kill)
        sub="$1"
        shift
        exec qs "$sub" -p "$cfg" "$@"
        ;;
    *) exec qs -p "$cfg" "$@" ;;
esac
