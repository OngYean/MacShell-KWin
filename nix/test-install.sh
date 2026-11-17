#!/bin/sh
# test-install.sh — checks the install outside Nix: what the top-level CMakeLists.txt puts under a prefix, that the
# installed launcher finds its configuration, and that `install.sh --uninstall` removes every file again (its list and
# CMake's must agree). The bridge is not built (MACSHELL_BRIDGE=OFF); a stand-in file takes its place.
# Also the optional features: install.sh's list, the Home Manager module's switches and the PKGBUILD's optdepends
# name the same things, and install.sh installs the packages of the chosen features only.
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
printf '#!/bin/sh\necho "sudo $*" >> "$LOG"\n' > "$work/bin/sudo"
printf '#!/bin/sh\n' > "$work/bin/pacman"
chmod +x "$work/bin/qs" "$work/bin/systemctl" "$work/bin/sudo" "$work/bin/pacman"
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

# ── optional features ──
feat_sh=$(sed -n '/^kde_features="/,/"$/p' "$root/install.sh" | sed 's/^kde_features="//')
names_sh=$(echo "$feat_sh" | cut -d'|' -f1)
names_nix=$(sed -n '/^  features = {$/,/^  };$/p' "$root/nix/home-manager.nix" | sed -n 's/^    \([A-Za-z]*\) = {$/\1/p')
[ -n "$names_sh" ] && [ -n "$names_nix" ] || fail "the feature lists of install.sh or nix/home-manager.nix were not found"
for k in $names_nix; do echo "$names_sh" | grep -qx "$k" || fail "feature $k is a Home Manager switch but install.sh does not ask about it"; done
for k in $names_sh; do
    # ydotool needs a system service, which Home Manager cannot set up
    [ "$k" = menuShortcuts ] || echo "$names_nix" | grep -qx "$k" || fail "install.sh asks about $k but the Home Manager module has no switch for it"
done
for p in $(echo "$feat_sh" | cut -d'|' -f3); do
    grep -q "^  '$p: " "$root/packaging/arch/PKGBUILD" || fail "$p (an optional feature in install.sh) is not in the PKGBUILD's optdepends"
done
ok "install.sh, the Home Manager module and the PKGBUILD list the same optional features"

features() { : > "$LOG"; PATH="$work/bin:$PATH" bash "$root/install.sh" --kde --features-only --features "$1" < /dev/null > "$work/features.log" 2>&1; }
features clipboardHistory || { cat "$work/features.log"; fail "install.sh --features-only"; }
if command -v cliphist >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
    grep -q "clipboardHistory .*already available" "$work/features.log" || fail "a feature whose programs are installed is not reported as available"
else
    grep -qx "sudo pacman -S --needed cliphist wl-clipboard" "$LOG" || { cat "$work/features.log" "$LOG"; fail "the chosen feature's packages, and only those, were not installed"; }
fi
features none || fail "install.sh --features none"
[ ! -s "$LOG" ] || { cat "$LOG"; fail "--features none installed something"; }
if features nope; then fail "an unknown feature name was accepted"; fi
ok "install.sh installs the packages of the chosen features only, and refuses a name it does not know"
