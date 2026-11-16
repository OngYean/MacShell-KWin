# Installing without Nix: install.sh for Plasma, a PKGBUILD, CMake install rules (2026-11-16)

`AGENTS.md` remains the authority. This file covers one request the user sent on 2026-11-16 for branch `pending-test`.

**State: written and pushed to `pending-test` on 2026-11-16 as `wip` commits. Nothing has run on Linux: no `makepkg`, no build of the bridge through the new CMake file, no install into a Plasma session.**

| ID | Request (user's words) | Status |
| --- | --- | --- |
| F18 | Adapt the current install (and uninstall) script to this current project state, and write a PKGBUILD. Add the updated installation methods into README.md. | written, untested on Linux |

## What was checked

- `sh nix/test-install.sh` passes on macOS with CMake 4.4 from a Python wheel (new, added to CI). It installs into a temporary prefix with `-DMACSHELL_BRIDGE=OFF`, checks the installed tree, the paths written into the unit and the service menu, that the installed `macshell` passes its own configuration to a stand-in `qs`, and that `install.sh --kde --uninstall` stops MacShell, turns autostart off and leaves no file under the prefix.
- `sh nix/test-macshell-session.sh` passes with new cases for `autostart replace|coexist|off`, a missing mode, and a unit managed by Home Manager. `sh nix/test-macshell.sh` passes unchanged.
- `bash -n` on `install.sh` and the `PKGBUILD`; `install.sh` option handling tried by hand (`--help`, a relative prefix, an unknown option, `--hyprland --help`).
- Arch package names, through archlinux.org's package search: `quickshell` (extra, 0.3.2), `kwayland`, `wlr-protocols`, `wayland-protocols`, `qt6-base`, `qt6-declarative`, `qt6-multimedia`, `qt6-svg`, `wl-clipboard`, `powerdevil` exist. **Not confirmed** (the site stopped answering): `plasma-workspace`, `kdialog`, `file`, `inotify-tools`, `cliphist`, `ydotool`, `fastfetch`, `spectacle`, `bluez-utils`, `networkmanager`, `cmake`, `systemd`, `dbus`, and that `wayland` ships `wayland-scanner`.
- Not checked: `shellcheck` (not installed here), `makepkg`, `namcap`, the bridge built through the top-level `CMakeLists.txt` (CI has a step for it), systemd reading the units from `share/systemd/user`, and everything at run time.

## What was written

- **`CMakeLists.txt` (top level)**: the one set of install rules outside Nix. Builds `kwin-bridge/` (option `MACSHELL_BRIDGE`, on by default) and installs `bin/macshell`, `bin/macshell-session`, `bin/macshell-kwin-bridge`, `share/macshell/shell/`, `share/systemd/user/macshell.service` and `macshell-fallback.service` (from `packaging/systemd/*.in`), `share/kio/servicemenus/macshell-pin-folder.desktop` and `share/plasma/shells/com.macshell.lock`. `flake.nix` does not use it.
- **`nix/macshell.sh`**: without `MACSHELL_CONFIG` (which the Nix wrapper sets) the configuration is `../share/macshell/shell` from the script, and the script's own directory is appended to `PATH` so the bridge beside it is found from a systemd unit.
- **`nix/macshell-session.sh`**: new `autostart replace|coexist|off`, the only persistent command. It enables or disables `macshell.service`; for `replace` it writes the plasmashell drop-in and `~/.config/environment.d/macshell.conf`, the same two things the Home Manager module writes. It refuses when `~/.config/systemd/user/macshell.service` is a symlink (Home Manager's).
- **`install.sh`**: a "KDE Plasma" block at the top. In a Plasma session or with `--kde` it checks for the build tools, builds in a temporary directory, installs to `~/.local` or `--prefix` (with `sudo` only when it cannot write there), and optionally runs `autostart`. `--uninstall` runs `macshell-session stop` and `autostart off`, then removes the paths in `kde_files`. Everything below the block is upstream's Hyprland installer, unchanged, reached in other sessions or with `--hyprland`.
- **`packaging/arch/PKGBUILD`**: `macshell-kwin-git`, from the repository's default branch, using the CMake rules.
- **Docs**: the README's Install section (a table of methods, Arch, `install.sh`, CMake, after installing, from a clone), the lock screen switch for these installs, and `PACKAGING.md`.

## Decisions

- **One CMake file instead of a file list in each of `install.sh` and the `PKGBUILD`.** Only `install.sh`'s uninstall list repeats it, and the test fails when they disagree.
- **`install.sh` keeps upstream's Hyprland installer.** No upstream code is deleted (`AGENTS.md` §11.5), and a merge from upstream touches one inserted block. The cost: the file does two unrelated things, chosen by the session.
- **The script installs no distribution packages.** Package names for Fedora, Debian and others could not be verified from here; it lists what is missing and prints a `pacman` line on Arch.
- **`share/macshell/shell`, not `share/macshell`.** With the prefix `~/.local`, `~/.local/share/macshell` is where upstream's Hyprland installer keeps its backups and tools; uninstalling must not delete them.
- **Units in `share/systemd/user`.** systemd's user manager searches `$XDG_DATA_HOME/systemd/user` and each `$XDG_DATA_DIRS/systemd/user`, so one location works for `~/.local`, `/usr/local` and `/usr`. Arch's guideline prefers `/usr/lib/systemd/user`; `namcap` may remark on it.
- **The lock-screen package is always installed** and does nothing until `PLASMA_DEFAULT_SHELL` names it; the README says how.

## Known gaps

- The repository's default branch (`main`) does not have the port or these files yet, so the `PKGBUILD` as written builds nothing useful until `pending-test` is merged. Until then: `source=("$pkgname::git+$url.git#branch=pending-test")`.
- `install.sh` in a Plasma session no longer accepts the Hyprland installer's options, which the Hyprland-only graphical installer and `macshell-update` pass.
- No update command for these installs: pull and install again.

## Test (a Linux machine with Plasma 6; Arch for steps 6 and 7)

1. In a Plasma session, from a clone: `./install.sh`. With a build tool missing it lists what is missing and stops. With everything present it builds and ends with the three commands to use.
2. `ls ~/.local/bin/macshell*` shows three programs. `systemctl --user cat macshell.service` prints the unit with `ExecStart=$HOME/.local/bin/macshell`.
3. `macshell-session start`: MacShell replaces `plasmashell`. `macshell-session status` shows `macshell.service: active`. `macshell-session stop`: `plasmashell` is back.
4. `macshell-session autostart replace`, log out and in: MacShell starts and `plasmashell` does not. `macshell-session autostart off`, log out and in: only `plasmashell`. Repeat with `coexist`: both.
5. In Dolphin, right-click a folder: "Pin to MacShell Dock" is there and works (test 7 in [`20`](20-dock-folders-tests.md)).
6. `./install.sh --uninstall`: MacShell stops, `plasmashell` runs, `ls ~/.local/bin/macshell*` finds nothing, `~/.config/macdock` is still there. If a Hyprland install's files were in `~/.local/share/macshell`, they are still there.
7. Arch: in `packaging/arch`, with the `source` line pointed at `pending-test`, `makepkg -si` builds and installs; `namcap` on the package and the `PKGBUILD` reports nothing serious; steps 3 to 5 work with the commands from `/usr/bin`; `sudo pacman -R macshell-kwin-git` removes it.
8. `./install.sh --prefix /usr/local` asks for the sudo password only for the copy, and `./install.sh --uninstall --prefix /usr/local` removes it.
9. Outside Plasma (or with `--hyprland`): `./install.sh --help` prints the Hyprland installer's help. Do not run that installer on the Plasma machine.
