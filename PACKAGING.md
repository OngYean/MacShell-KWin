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
- Nothing in these outputs has been built or run yet; follow `handoff/06-kwin-testing-guide.md`.

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

## Conventional installer

`install.sh` remains the existing upstream-style, package-manager-based **Hyprland** installer. It can install system packages or enable services and edits Hyprland configuration. Do not use it in a Plasma/KWin session or as part of declarative Nix deployment.

A KWin-aware conventional install mode should be added only after the KWin backend and runtime requirements are implemented and tested. Until then, retain the original Plasma session and its KDE services unchanged.
