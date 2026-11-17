# Packaging and development installs

## Nix development package

`flake.nix` packages the checked-in `MacShell/` Quickshell configuration and its Quickshell launcher. Nixpkgs is sourced from `nixos-unstable` and pinned by `flake.lock`; update that pin intentionally and review the lock-file diff.

The current shell still imports and dispatches to Hyprland APIs. This package is therefore named `macshell-hyprland` and is **not** a KWin-compatible build. It does not change host configuration, install services, configure autostart, or replace any Plasma component.

From the repository root:

```sh
nix run .#macshell-hyprland
nix build .#macshell-hyprland
nix develop
```

`nix develop` provides Quickshell, Qt QML tooling, ShellCheck, CMake, pkg-config, KWayland and Wayland client development files. The runtime package supplies Quickshell; the existing shell's other external programs and compositor APIs still need to be available in the user session.

## KDE Plasma (KWin) build: `kwin-port` branch, untested

```sh
nix run .#macshell                         # MacShell with the backend detected at start (KWin under Plasma, Hyprland under Hyprland)
nix run .#macshell -- ipc call spotlight toggle   # talk to the running instance (wrapper passes -p <store path>)
nix run .#kwin-bridge -- --check           # sanitized KWin bridge summary (counts only)
nix run .#macshell-session -- status       # status | start | stop | replace | restore (per login, nothing persistent)
nix develop --command qs -p ./MacShell     # development: run straight from the work tree, bridge on PATH
```

- `packages.macshell` contains the configuration in the store, Quickshell, the `macshell-kwin-bridge` helper (see `kwin-bridge/README.md`), QtMultimedia on the QML path (`LiveWall.qml` needs it), and the `macshell-session` switcher.
- `homeManagerModules.macshell` (`programs.macshell.enable`, `.autostart`, `.package`): installs the package and defines `macshell.service`, wanted by `plasma-workspace.target` only when `autostart = true`. It never disables plasmashell or any KDE service.
- CI (`.github/workflows/kwin-port.yml`) builds these outputs, evaluates the Home Manager module, and runs the bridge and MacShell against a headless KWin (`nix/kwin-smoke.sh`). Nothing has run in a real Plasma session yet; follow `handoff/06-kwin-testing-guide.md`.

A separate, deliberately limited KWin protocol diagnostic is available during development:

```sh
nix run .#kwin-backend-probe
nix run .#kwin-backend-probe -- --menu-check
nix build .#kwin-backend-probe
```

It checks access to KWin's privileged Plasma Window Management protocol in the live session and reports a compact summary (protocol version, window count, active-window presence, AppMenu registration-global availability, active AppMenu-address presence, and workspace-read availability). The optional `--menu-check` mode makes one read-only D-BusMenu `GetLayout` request for the active window's registered address and reports success/root-item count without menu labels. `--menu-watch` streams the real active menu tree (including labels) to the isolated Quickshell POC and accepts its validated menu-event commands; never run it with raw output exposed or outside that fixture. These are not supported public APIs or a production backend; see `poc/kwin-backend-probe/README.md` and `poc/global-menu/README.md` before running them. The optional `--watch` mode emits sensitive window metadata as NDJSON and is intended only for the local QML bridge fixture.

To launch the real-data renderer POC:

```sh
nix develop --command qs --verbose --path ./poc/global-menu/shell.qml
```

See `poc/global-menu/README.md` for its trust boundary, current feature gaps and the untracked-source workaround.

## Installing outside Nix

The top-level `CMakeLists.txt` holds the install rules for every route that is not Nix: it builds `kwin-bridge/` (unless `-DMACSHELL_BRIDGE=OFF`) and installs, under the prefix, `bin/macshell` (`nix/macshell.sh`), `bin/macshell-session`, `bin/macshell-kwin-bridge`, `share/macshell/shell/` (the `MacShell/` tree), the two systemd user units generated from `packaging/systemd/*.in`, Dolphin's service menu and the lock-screen package assembled by `MacLock/kde/build.sh`. `flake.nix` does not use it.

- `install.sh` runs it in a KDE Plasma session, or with `--kde`: it checks for the build tools, builds in a temporary directory and installs to `~/.local` (or `--prefix`). `--uninstall` removes the paths listed in its `kde_files`. In any other session, or with `--hyprland`, the script is still the upstream **Hyprland** installer below its "KDE Plasma" block: unchanged, unsupported here, and it installs the original project, not this fork.
- `packaging/arch/PKGBUILD` builds `macshell-kwin-git` from the repository's default branch with the same rules.
- `macshell-session autostart replace|coexist|off` is the persistent switch for these installs (the Home Manager module's `autostart` and `mode`).
- `sh nix/test-install.sh` installs into a temporary prefix without the bridge and checks the result, the installed launcher, and that `install.sh --uninstall` leaves no file behind. CI also builds the whole thing, bridge included, in the development shell.

### Optional features

Programs MacShell does without when they are missing (kdialog, cliphist, …) are a choice in every route, and the three lists must name the same things:

- `nix/home-manager.nix`: the `features` attribute set (name, default, description, packages) becomes `programs.macshell.features.<name>`, and a switch that is on adds its packages to `home.packages`. The `macshell` package's wrapper carries no optional program.
- `packaging/arch/PKGBUILD`: `optdepends`, each with what it gives.
- `install.sh`: `kde_features` (name, programs to look for, pacman / dnf / apt packages, description). `kde_optional` asks about each missing one on a terminal, or takes `--features`, and installs the chosen packages in one package-manager call.

To add one, add it to all three; `sh nix/test-install.sh` fails when a Home Manager switch has no entry in `install.sh` (or the other way round, apart from `menuShortcuts`, whose `ydotoold` service Home Manager cannot set up) or when a pacman package in `install.sh` is not in `optdepends`. System services (PowerDevil, NetworkManager, BlueZ, power-profiles-daemon) are only listed in `optdepends`.

None of these routes has run on a real system: no `makepkg`, no install into a Plasma session.
