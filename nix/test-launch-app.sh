#!/bin/sh
# test-launch-app.sh — checks MacShell/assets/launch-app.sh against stand-in systemd-run / systemd-escape that only log.
# An app must start as its own systemd user service, with its arguments intact, and directly when systemd-run can't.
#   sh nix/test-launch-app.sh            (no systemd or Nix needed)
# shellcheck disable=SC2016  # the stub bodies are written literally: they expand when the stubs run
set -eu
here=$(cd "$(dirname "$0")" && pwd)
script="$here/../MacShell/assets/launch-app.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin" "$work/nobin" "$work/a dir"
log="$work/log"

stub() { # directory, name, body
    printf '#!/bin/sh\n%s\n' "$3" > "$work/$1/$2"
    chmod +x "$work/$1/$2"
}
# one logged line per argument, so an argument that was split or joined shows
stub bin systemd-run '[ -e "$LOG.fail" ] && exit 1; for a in "$@"; do echo "systemd-run: $a" >> "$LOG"; done'
stub bin systemd-escape 'shift; IFS=/; set -f; set -- $1; IFS=-; printf "%s\n" "$*"'
# the app itself, for the direct start: logs its directory and arguments
stub bin theapp 'echo "theapp in $(pwd -P)" >> "$LOG"; for a in "$@"; do echo "theapp: $a" >> "$LOG"; done'
stub nobin theapp 'echo "theapp in $(pwd -P)" >> "$LOG"; for a in "$@"; do echo "theapp: $a" >> "$LOG"; done'

run() { # PATH directory, then launch-app.sh's arguments. Nothing else is on PATH: the host's systemd-run is never used
    : > "$log"
    d="$1"
    shift
    PATH="$work/$d" LOG="$log" HOME="$work" /bin/sh "$script" "$@"
}
check() { # name, expected, actual
    [ "$2" = "$3" ] || { printf 'FAIL: %s\nwant: %s\ngot:  %s\n' "$1" "$2" "$3"; exit 1; }
    echo "ok: $1"
}

run bin org.kde.dolphin 1a2b "" theapp --new-window "/a path/with spaces"
check "a systemd user service in app.slice, arguments intact" "systemd-run: --user
systemd-run: --quiet
systemd-run: --collect
systemd-run: --service-type=exec
systemd-run: --slice=app.slice
systemd-run: --property=ExitType=cgroup
systemd-run: --unit=app-macshell-org.kde.dolphin@1a2b.service
systemd-run: --working-directory=$work
systemd-run: --
systemd-run: theapp
systemd-run: --new-window
systemd-run: /a path/with spaces" "$(cat "$log")"

run bin a/b 7 "$work/a dir" theapp
check "the entry's working directory and an escaped id" "systemd-run: --unit=app-macshell-a-b@7.service
systemd-run: --working-directory=$work/a dir" "$(grep -E -- '--(unit|working-directory)=' "$log")"

touch "$log.fail"
run bin org.kde.dolphin 1a2b "$work/a dir" theapp "two words"
rm "$log.fail"
check "systemd-run fails: started directly, in the working directory" "theapp in $(cd "$work/a dir" && pwd -P)
theapp: two words" "$(cat "$log")"

run nobin org.kde.dolphin 1a2b "" theapp one
check "no systemd-run: started directly" "theapp: one" "$(grep '^theapp: ' "$log")"
