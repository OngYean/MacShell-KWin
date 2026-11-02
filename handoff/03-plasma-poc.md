# Independent task: safe minimal Plasma/KWin proof of concept

This brief is self-contained. Read `AGENTS.md` before work. This lane prepares and, only after explicit readiness from the user, validates the smallest Quickshell panel/dock under Plasma Wayland.

## User/session state

The target is latest upstream Plasma 6 Wayland with KWin. The user is in a Hyprland session now. They will enable `services.desktopManager.plasma6.enable` in their host configuration themselves and will notify us once they enter a standard Plasma session. **Do not change that configuration, switch sessions, install packages, run an installer, disable plasmashell or edit autostart.**

Workspace is `MacShell-KWin`; current HEAD is `bcadc79` (`docs(agents): add Git commit and validation rules`). The initial source-audit baseline was `51db0bab6997da310d2aacfaa7084740ec44ad4a` and is historical. The existing full MacShell shell imports Hyprland APIs and cannot be used as proof that MacShell works under KWin. No KWin runtime test has been performed.

Nix development baseline added in `flake.nix`/`flake.lock` packages only the current Hyprland configuration. It pins Quickshell 0.3.2 through Nixpkgs unstable; `nix flake check --no-build --all-systems` passed. Do not treat it as KWin support.

## Task before the session is ready

Prepare a short, non-invasive test runbook. It must separate preparation from user-authorized execution and include:

- how to verify active session/compositor, installed KWin/Plasma/Quickshell versions and advertised Wayland globals;
- how to launch an isolated minimal Quickshell layer-shell panel under KWin without importing MacShell's Hyprland modules;
- how to leave plasmashell running and avoid overlapping the native Plasma panel/Global Menu;
- how to test KWin decorations/Klassy remain intact, layer placement/keyboard interaction, scaling, output changes, restart/rollback and relevant logs;
- how to test a minimal dock surface without app/window enumeration until a supported backend exists;
- battery/GPU precautions (no live capture, no forced NVIDIA device selection).

Do not run GUI/session commands while the user remains in Hyprland. If creating a PoC source file, keep it isolated (suggested `poc/kwin-basics/`) and make no autostart or host-config changes; first confirm the target Quickshell QML API from the pinned package.

## Task after user's readiness signal

Ask the user to confirm the Plasma Wayland session is active, then run only the reversible/manual checks they authorize. Keep the original Plasma desktop as recovery path. Record actual versions, protocol globals, test commands and observed behavior. Do not advance to replacing plasmashell.

## Acceptance for this lane

- A minimal panel renders under KWin on the correct layer without suppressing or duplicating KDE services.
- A basic dock surface renders without pretending to enumerate windows.
- Existing KWin decorations, including Klassy, remain intact.
- Rollback is a manual process termination/relogin, not an installer or configuration rollback requiring root.
- Unsupported windows/workspace/capture features are listed explicitly.
