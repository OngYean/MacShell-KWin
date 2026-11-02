# Independent task: Nix packaging and conventional installer

This brief is self-contained. Read `AGENTS.md` first; it governs reproducibility, rollback, and host safety.

## User direction

Use latest upstream versions as the development target. The user plans to enable the latest Plasma 6 desktop in their host configuration themselves and will notify the project after entering Plasma Wayland. Do not edit the host Nix configuration, switch sessions, run installers, install packages imperatively, or modify session services.

## Repository and current packaging

There is no external NixOS/Home Manager configuration repository in this workspace. The user requested that the MacShell source repository itself be usable during development.

Current repo HEAD is `bcadc79` (`docs(agents): add Git commit and validation rules`). The initial source-audit baseline was `51db0bab6997da310d2aacfaa7084740ec44ad4a` and is historical. Packaging baseline files added since then:

- `flake.nix`: packages `MacShell/` and wraps `pkgs.quickshell` as `macshell-hyprland`; provides app outputs and a development shell.
- `flake.lock`: pins `nixos-unstable` at `0bb2eedc20e4739f29e8045034f2828ad7054f8f` (2026-11-01); Quickshell is `0.3.2` at that revision.
- `PACKAGING.md`: commands and clear warning about the backend.

`nix flake check path:. --no-build --all-systems` passed, but the package has **not** been built or launched. This is a development source package, not a finished KWin deployment.

`MacShell/shell.qml`, `MacBar.qml` and `MacDock.qml` still depend on Hyprland APIs. The package is correctly named `macshell-hyprland`; do not rename it to a KWin package or claim KWin compatibility before an actual backend exists.

The existing root `install.sh` is a large upstream-style installer. It uses package managers, can enable services and edits Hyprland configuration/autostart. It defaults to upstream `0-ss/MacShell` behavior. It is **not** suitable for KWin or normal declarative Nix deployment and must not be run during this task.

## Work requested

Review the current flake and provide a staged plan for the project's final declarative deployment and conventional installation options:

- keep source-code port separate from Nix configuration ownership;
- use existing Nixpkgs packages and a lock file; don't introduce an external host-config layout in this repo;
- eventually package the KWin-capable Quickshell configuration and required runtime dependencies, but only after backend APIs are available;
- use a reversible user-level autostart/service integration; preserve the Plasma session as fallback and do not disable plasmashell/KDE services prematurely;
- plan a safe KWin-aware conventional installer mode only when the code is KWin-ready. It must be explicit, non-destructive, detect the session, avoid enabling/disabling unrelated KDE services, and have a dry-run/uninstall/rollback story;
- preserve current Hyprland install instructions separately if upstream behavior remains supported;
- document GPU-sensitive defaults and avoid unconditional preview/capture dependencies.

Do not change `install.sh` or the current flake in this research lane unless assigned a specific implementation with a disjoint file scope. Do not package `MacLock` as a KDE lock-screen replacement; KDE native locking must remain authoritative until an alternative is proven secure.

## Deliverable

Return a deployment matrix (development flake vs final Nix deployment vs conventional installer), shortcomings in the existing flake, recommended future file/output structure, and exact gates before enabling KWin autostart. Clearly distinguish verified package evaluation from package build/runtime verification.
