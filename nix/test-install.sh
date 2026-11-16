#!/bin/sh
# test-install.sh — checks the install outside Nix: what the top-level CMakeLists.txt puts under a prefix, that the
# installed launcher finds its configuration, and that `install.sh --uninstall` removes every file again (its list and
# CMake's must agree). The bridge is not built (MACSHELL_BRIDGE=OFF); a stand-in file takes its place.
#   sh nix/test-install.sh            (needs cmake, make and bash; no Qt, KWayland, Plasma or Nix)
# shellcheck disable=SC2016  # the stub bodies are written literally: they expand when the stubs run
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
prefix="$work/prefix"
mkdir "$work/bin" "$work/home"
printf '#!/bin/sh\necho "qs $*" >> "$LOG"\n' > "$work/bin/qs"
printf '#!/bin/sh\necho "systemctl $*" >> "$LOG"\n' > "$work/bin/systemctl"
chmod +x "$work/bin/qs" "$work/bin/systemctl"
LOG="$work/log"
export LOG

ok() { echo "ok: $1"; }
fail() { echo "FAIL: $1"; exit 1; }

{ cmake -S "$root" -B "$work/build" -DMACSHELL_BRIDGE=OFF -DCMAKE_INSTALL_PREFIX="$prefix" \
    && cmake --build "$work/build" && cmake --install "$work/build"; } > "$work/cmake.log" 2>&1 || { cat "$work/cmake.log"; fail "cmake install"; }
ok "cmake configures, builds and installs without the bridge"

for f in bin/macshell bin/macshell-session share/macshell/shell/assets/list-folder.sh share/kio/servicemenus/macshell-pin-folder.desktop; do
    [ -x "$prefix/$f" ] || fail "$f is not installed as an executable"
done
for f in share/macshell/shell/shell.qml share/macshell/shell/VERSION share/systemd/user/macshell-fallback.service \
    share/plasma/shells/com.macshell.lock/metadata.json share/plasma/shells/com.macshell.lock/contents/lockscreen/ui/LockScreen.qml; do
    [ -f "$prefix/$f" ] || fail "$f is not installed"
done
ok "the launchers, the configuration, the units, the service menu and the lock package are in place"

grep -qx "ExecStart=$prefix/bin/macshell" "$prefix/share/systemd/user/macshell.service" || fail "macshell.service does not start the installed macshell"
grep -qx "Exec=$prefix/bin/macshell ipc call dock pinFolder %f" "$prefix/share/kio/servicemenus/macshell-pin-folder.desktop" || fail "the service menu does not call the installed macshell"
grep -qx "MimeType=inode/directory;" "$prefix/share/kio/servicemenus/macshell-pin-folder.desktop" || fail "the service menu lost its MimeType line"
ok "the unit and the service menu name the installed macshell"

: > "$LOG"
PATH="$work/bin:$PATH" HOME="$work/home" "$prefix/bin/macshell" ipc call spotlight toggle
[ "$(cat "$LOG")" = "qs ipc -p $prefix/bin/../share/macshell/shell call spotlight toggle" ] || { cat "$LOG"; fail "the installed launcher does not pass its own configuration to qs"; }
ok "the installed launcher finds its configuration without MACSHELL_CONFIG"

: > "$prefix/bin/macshell-kwin-bridge"
: > "$LOG"
PATH="$work/bin:$PATH" HOME="$work/home" XDG_CURRENT_DESKTOP='' bash "$root/install.sh" --kde --uninstall --prefix "$prefix" > "$work/uninstall.log" 2>&1 || { cat "$work/uninstall.log"; fail "install.sh --uninstall"; }
left=$(find "$prefix" ! -type d)
[ -z "$left" ] || { echo "$left"; fail "install.sh --uninstall left files behind: its list (kde_files) and CMakeLists.txt disagree"; }
grep -qx "systemctl --user stop macshell.service" "$LOG" || fail "uninstall did not stop MacShell"
grep -qx "systemctl --user disable macshell.service" "$LOG" || fail "uninstall did not turn autostart off"
ok "install.sh --uninstall stops MacShell, turns autostart off and removes every installed file"
