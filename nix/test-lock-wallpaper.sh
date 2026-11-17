#!/bin/sh
# test-lock-wallpaper.sh — checks MacShell/assets/lock-wallpaper.sh against stand-in kreadconfig6 / kwriteconfig6 that
# only log: KDE's lock wallpaper is written only while MacLock is KDE's lock screen, and only for a picture that exists.
#   sh nix/test-lock-wallpaper.sh        (no Plasma or Nix needed)
# shellcheck disable=SC2016  # the stub bodies are written literally: they expand when the stubs run
set -eu
here=$(cd "$(dirname "$0")" && pwd)
script="$here/../MacShell/assets/lock-wallpaper.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
printf '#!/bin/sh\ncat "$RC" 2>/dev/null\n' > "$work/bin/kreadconfig6"
printf '#!/bin/sh\necho "$*" >> "$LOG"\n' > "$work/bin/kwriteconfig6"
chmod +x "$work/bin/kreadconfig6" "$work/bin/kwriteconfig6"
pic="$work/my wall.png"
: > "$pic"

fail=0
run() { # what, PLASMA_DEFAULT_SHELL, plasmashellrc's ShellPackage, picture, expected number of writes
    rm -f "$work/rc"
    : > "$work/log"
    [ -z "$3" ] || echo "$3" > "$work/rc"
    PATH="$work/bin:$PATH" LOG="$work/log" RC="$work/rc" PLASMA_DEFAULT_SHELL="$2" sh "$script" "$4"
    n=$(wc -l < "$work/log")
    [ "$((n))" = "$5" ] || { echo "test-lock-wallpaper: FAIL $1 ($((n)) writes, expected $5)"; fail=1; }
}
run "MacLock named by the variable" com.macshell.lock "" "$pic" 2
grep -qx -- "--file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image" "$work/log" \
    && grep -qx -- "--file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image file://$pic" "$work/log" \
    || { echo "test-lock-wallpaper: FAIL the two keys KDE's lock screen reads"; cat "$work/log"; fail=1; }
run "MacLock named by plasmashellrc" "" com.macshell.lock "$pic" 2
run "Plasma's own lock screen" "" "" "$pic" 0
run "plasmashellrc names another shell, whatever the variable says" com.macshell.lock org.kde.plasma.desktop "$pic" 0
run "a picture that is gone" com.macshell.lock "" "$work/gone.png" 0
[ "$fail" = 0 ] && echo "test-lock-wallpaper: ok"
exit "$fail"
