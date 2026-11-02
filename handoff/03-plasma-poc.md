# Independent task: safe minimal Plasma/KWin proof of concept

This brief is self-contained. Read `AGENTS.md` before work. This lane maintains and validates the smallest isolated Quickshell panel/dock under the user's active Plasma Wayland session.

## User/session state

The user is now in a verified Plasma/KWin `6.8.2` Wayland session with Qt `6.12.0`. **Do not change host configuration, switch sessions, install packages, run an installer, disable plasmashell or edit autostart.**

Workspace is `MacShell-KWin`; current committed HEAD is `f9037d5` (`docs(handoff): refresh repository state references`). The initial source-audit baseline was `51db0bab6997da310d2aacfaa7084740ec44ad4a` and is historical; POC work is uncommitted. The existing full MacShell shell imports Hyprland APIs and cannot be used as proof that MacShell works under KWin.

The user visually verified `poc/kwin-basics/shell.qml` in the active KWin session: the temporary top bar and inert dock appeared on `eDP-1` as expected, disappeared after exit, and did not shift application work areas. Earlier runs logged `eDP-1 1920x1080` and `Configuration Loaded`; the bounded process exits through `timeout` (124), as expected. This acceptance covers only this isolated layer-shell fixture—not Klassy, full MacShell, or the separate backend status fixture. Quickshell logs a non-fatal portal warning because `org.quickshell` app info is unavailable in the development environment.

The development flake pins Quickshell `0.3.2` and declares KWayland `6.8.2` plus build tools for a separate backend probe. `XDG_CACHE_HOME=/tmp nix flake check path:. --no-build --all-systems` passed after the latest flake edits. The full packaged Hyprland shell is not KWin support.

## Current POC and session findings

- `poc/kwin-basics/shell.qml` uses only `PanelWindow` and the Quickshell Wayland layer-shell API. It does not import MacShell's Hyprland modules, enumerate windows, capture frames, or create persistent configuration. The user has visually accepted its placement and cleanup on `eDP-1`, including no change to application work areas.
- The active Plasma panel is on `DP-2`; the inspected layout has no panel on `eDP-1`. KScreen enumeration and Quickshell's screen list have different order on this machine, so the fixture selects output by name (`eDP-1`) and hides both surfaces if it is absent.
- The top panel and inert dock use the `Top` layer, `ExclusionMode.Ignore`, and no keyboard focus. The user visually confirmed the surfaces appeared as expected on `eDP-1`, disappeared after exit, and did not shift application work areas. Pointer/keyboard behavior and display hotplug remain unconfirmed.
- Initial test code used Quickshell screen index 1 and selected `DP-2`; the 12-second run ended automatically. The code was corrected to select by output name before the successful `eDP-1` log.
- KWin currently uses Breeze (`org.kde.breeze`), not Klassy. Do not change the user's decoration setting. Klassy compatibility cannot be accepted until Klassy is installed and selected by the user.

## Next checks

The basic panel/dock visual check is accepted. Keep plasmashell running and use the documented foreground command in `poc/kwin-basics/README.md` only for repeatable manual inspection; `Ctrl+C` stops the fixture. A separate status fixture at `poc/kwin-backend-probe/shell.qml` loaded under Quickshell for 30 seconds and was stopped by timeout; the user has not separately confirmed that panel's rendered status text. Next verify a real exported application menu and keep testing decorations separately. The current decoration is Breeze, so Klassy is not tested. Do not enable autostart or replace any Plasma component.

## Acceptance for this lane

- A minimal panel and inert dock are visually confirmed by the user under KWin on the intended output; they disappear at exit and do not shift work areas.
- The backend-status panel is only startup/runtime-validated; its visual state has not been independently accepted, and it is not a production shell.
- Existing KWin decorations remain intact; Klassy-specific behavior remains unverified until Klassy is selected.
- Rollback is a manual process termination/relogin, not an installer or configuration rollback requiring root.
- Unsupported windows/workspace/capture features are listed explicitly.
