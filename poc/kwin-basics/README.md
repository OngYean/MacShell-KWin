# Minimal Plasma/KWin layer-shell proof of concept

This isolated configuration tests only Quickshell startup and basic top/dock layer surfaces. It does not import `MacShell/` or use any Hyprland API, and it does not enumerate or activate windows, capture previews, install itself, or alter Plasma configuration.

## Verified environment at creation

- Plasma / KWin: `6.8.2`, Wayland session.
- Quickshell: `0.3.2`, supplied by this repository's `nix develop` environment (not currently installed on the session `PATH`).
- `kscreen-doctor -o` lists `DP-2` first and `eDP-1` second; the existing Plasma bottom panel is on `DP-2`, while the inspected layout has no panel on `eDP-1`.
- Quickshell 0.3.2's screen list order is different: its index 1 resolved to `DP-2` during the initial run. The fixture now selects `eDP-1` by output name rather than assuming indexes match.
- Both temporary surfaces target `eDP-1` by name, use the Wayland `Top` layer, set `ExclusionMode.Ignore`, and do not request keyboard focus. This avoids reserving desktop space and leaves the native panel/services in place.
- KWin's selected decoration is Breeze (`org.kde.breeze`), not Klassy; no decoration setting was changed.

Output names and panel layout can change after hotplug or configuration changes. Re-check `kscreen-doctor -o` and the Plasma panel layout before launching; the fixture deliberately hides itself if `eDP-1` is absent.

## Run manually

From the repository root, start the test in the foreground:

```sh
nix develop --command qs --path ./poc/kwin-basics/shell.qml
```

The two test surfaces appear on `eDP-1` only. The foreground process logs the selected output and remains attached to the terminal. Press `Ctrl+C` to stop it; no persistent configuration or autostart is created. Keep `plasmashell` running.

If `eDP-1` is absent, the QML reports that fact and keeps both surfaces hidden. Review the Quickshell startup output for QML or Wayland errors. The dock's `A/B/C` marks are deliberately inert placeholders, not application icons or window-management functionality.

The first timed runtime check mistakenly targeted Quickshell screen index 1, which was `DP-2`; it ran for 12 seconds and then exited on timeout. That exposed the output-order mismatch, and the fixture was changed to select `eDP-1` by name. Follow-up 12-second and 8-second runs both logged `eDP-1 1920x1080` and `Configuration Loaded`; each ended through its expected timeout (exit 124). Startup output had no QML or layer-shell error. The portal emitted a non-fatal warning that app info for `org.quickshell` is unavailable in the development environment.

## Scope and remaining checks

A successful startup/log is not visual acceptance. Confirm the surfaces are visibly placed at the top and bottom edges of `eDP-1`, are not obscured or interactive, and disappear after stopping Quickshell. Verify KWin decorations on ordinary application windows remain unchanged; the current decoration is Breeze, so Klassy is not tested. `qmllint` reports only unqualified-access style warnings for QML `parent`/delegate context references; it reports no syntax errors. Hotplug, scaling, sleep/resume, multiple display placement, global menus, window management and GPU power behavior are not tested by this fixture.

`kwin-window-probe.js` is a separate read-only backend experiment. KWin 6.8.2 assigns each loaded script a D-Bus object at `/Scripting/Script<ID>`; use the ID returned by `loadScript`, not the global `start()` method. A uniquely named probe loaded as ID `1`, ran through `/Scripting/Script1`, and unloaded (`isScriptLoaded` changed true to false). The per-script call returned successfully, but the count-only `console.info` output was not visible in the queried journal, so the window count is not independently verified. An earlier attempt addressed `/Scripting/Script0` instead of the returned ID and may have run a pre-existing script; no existing script was stopped or unloaded and no persistent configuration was changed. Do not repeat that incorrect path. The C++ protocol-access experiment is separately documented at `poc/kwin-backend-probe/README.md`.
