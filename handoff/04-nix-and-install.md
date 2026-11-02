# Independent task: Nix packaging and conventional installer

This brief is self-contained. Read `AGENTS.md` first; it governs reproducibility, rollback, and host safety.

## User direction

Use latest upstream versions as the development target. The user is now in a verified Plasma/KWin `6.8.2` Wayland session with Qt `6.12.0`; Quickshell `0.3.2` is available via the repository dev flake. Do not edit host Nix configuration, switch sessions, run installers, install packages imperatively, or modify session services.

## Repository and current packaging

There is no external NixOS/Home Manager configuration repository in this workspace. The user requested that the MacShell source repository itself be usable during development.

Current committed repo HEAD is `f9037d5` (`docs(handoff): refresh repository state references`). The initial source-audit baseline was `51db0bab6997da310d2aacfaa7084740ec44ad4a` and is historical; the POC and session updates are uncommitted. Packaging baseline files added since then:

- `flake.nix`: packages `MacShell/` and wraps `pkgs.quickshell` as `macshell-hyprland`; provides app outputs and a development shell. A separate `kwin-backend-probe` package uses `pkgs.kdePackages.kwayland` (6.8.2) and is not a shell deployment.
- `flake.lock`: pins `nixos-unstable` at `0bb2eedc20e4739f29e8045034f2828ad7054f8f` (2026-11-01); Quickshell is `0.3.2` at that revision.
- `PACKAGING.md`: commands and clear warning about the backend.

On 2026-11-02, `XDG_CACHE_HOME=/tmp nix flake check path:. --no-build --all-systems` and `nix build path:.#kwin-backend-probe --no-link -L` passed. In the live Plasma session, KWin advertised protocol v21 and AppMenu; with native-Wayland KWrite active the address settled to present and `nix run path:.#kwin-backend-probe -- --menu-check` retrieved `GetLayout` (8 root entries). A sanitized `--menu-watch` check counted 8 root, 132 total and 96 labeled items. The basic panel/dock POC was visually accepted by the user. The separate Global Menu renderer loaded in bounded Quickshell runs; its visual acceptance and D-BusMenu event/activation path remain unverified. `nix develop` currently fails for untracked helper source, so the renderer was launched with a temporary `nix shell --impure --expr` using the locked Quickshell and probe derivations. This is an opt-in POC only—not a packaged KWin shell or deployment. The existing Hyprland package has not been built.

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
