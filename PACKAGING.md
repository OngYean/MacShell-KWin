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

`nix develop` provides Quickshell, Qt QML tooling and ShellCheck. The runtime package supplies Quickshell; the existing shell's other external programs and compositor APIs still need to be available in the user session.

## Conventional installer

`install.sh` remains the existing upstream-style, package-manager-based **Hyprland** installer. It can install system packages or enable services and edits Hyprland configuration. Do not use it in a Plasma/KWin session or as part of declarative Nix deployment.

A KWin-aware conventional install mode should be added only after the KWin backend and runtime requirements are implemented and tested. Until then, retain the original Plasma session and its KDE services unchanged.
