#!/bin/sh
# Starts an application for MacShell on KDE (shell.qml, hub.launch).
#   launch-app.sh <application id> <random suffix> <working directory, or ""> <command> [arguments...]
# The app becomes its own systemd user service in app.slice, named the way the desktop-environment cgroup convention asks
# (app-<launcher>-<id>@<random>.service, systemd.io/DESKTOP_ENVIRONMENTS), like Plasma's own launchers. It is then not a
# child of the shell: it has its own cgroup, so stopping or restarting macshell.service doesn't take it down, and it gets
# the session's environment instead of the shell wrapper's (QML_IMPORT_PATH, QT_PLUGIN_PATH).
# ExitType=cgroup keeps the unit until its last process exits (launchers that fork and exit). --service-type=exec makes
# systemd-run fail when the program can't be executed. If systemd-run is missing or fails (no user manager, an older
# systemd), the command is started directly, as MacShell always did.
id="$1"
rnd="$2"
wd="$3"
shift 3

if command -v systemd-run >/dev/null 2>&1 && esc=$(systemd-escape -- "$id" 2>/dev/null); then
    # a user service starts in the home directory by default
    systemd-run --user --quiet --collect --service-type=exec --slice=app.slice --property=ExitType=cgroup \
        --unit="app-macshell-$esc@$rnd.service" --working-directory="${wd:-$HOME}" -- "$@" && exit 0
fi
if [ -n "$wd" ]; then cd "$wd" 2>/dev/null || true; fi
exec "$@"
