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
    *)
        # Settings → Appearance → "KDE's text rendering" (saved by MacDock.qml as "nativeText": true). Qt decides how it
        # draws text once, at start: with QML_DISABLE_DISTANCEFIELD set, Qt Quick uses the system's rasterizer, which
        # follows KDE's font settings. Set the variable yourself to force it either way ("" keeps Qt's own rendering).
        if [ -z "${QML_DISABLE_DISTANCEFIELD+set}" ]; then
            settings="${HOME}/.config/macdock/settings.json"
            if [ -r "$settings" ]; then
                while IFS= read -r line; do
                    case "$line" in *'"nativeText": true'*) export QML_DISABLE_DISTANCEFIELD=1 ;; esac
                done < "$settings"
            fi
        elif [ -z "$QML_DISABLE_DISTANCEFIELD" ]; then
            unset QML_DISABLE_DISTANCEFIELD
        fi
        exec qs -p "$cfg" "$@"
        ;;
esac
