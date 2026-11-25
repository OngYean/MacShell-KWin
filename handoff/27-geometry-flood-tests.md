# MacShell stutters while animated game launchers run (2026-11-25)

`AGENTS.md` remains the authority. This file covers one bug the user reported for branch `pending-test`.

**State: written as a `wip` commit on `pending-test`. Not compiled locally (no Qt or KWayland headers on the macOS dev box); CI builds the bridge. Not run in Plasma.**

| ID | Report (user's words) | Status |
| --- | --- | --- |
| B17 | When multiple game launchers (uses openGL to render fancy animation) under proton run simultaneously, macshell would stutter and drop in framerates while kwin is still perfectly responsive. | cause found, fix written, untested |

## How the cause was found

The user's tests ruled out, in order:

- **GPU load:** on an NVIDIA-only machine, GPU and VRAM usage stayed low while MacShell stuttered.
- **MacShell's own effects:** Game Mode (which pauses the glass on KWin) and KWin's blur on or off changed nothing.
- **The deciding clue:** with the same launchers inside **gamescope**, MacShell did not stutter. KWin then sees one gamescope window instead of the launchers' Xwayland windows.

A second `macshell-kwin-bridge` piped into a small counting script showed hundreds of window-list updates per 30 s while the launchers ran, almost all of them `x`/`y`/`width`/`height` changes. The bridge coalesced every window change at 25 ms, so a window whose geometry changes every frame produced up to 40 full window lists a second. Each one is parsed on MacShell's GUI thread and replaces `windowList`, every window adapter's `info` and the `clients` / `activeWindow` bindings (`MacShell/backends/compositor/KWinBackend.qml`).

## The change

`kwin-bridge/main.cpp`: `PlasmaWindow::geometryChanged` no longer starts the 25 ms timer. It starts its own 250 ms timer (`m_geometryTimer`) instead, which emits the window list at most 4 times a second. Every other change (title, state, active window, desktops, …) still goes out after 25 ms and carries the current geometry with it. `emitWindows()` already drops a list identical to the last one, so the two timers can't send duplicates.

## Decisions and limits

- **Who reads geometry on KWin:** the Dock's smart-hide (`busyDebounce`, 120 ms), the fullscreen / covered check (`coverDelay`, 300 ms), the minimize targets' screen and the Settings window's glass sidebar. None needs more than 4 updates a second. `WindowDecor.qml` (titlebar dragging) is Hyprland-only. Window capture for the glass is off on KWin.
- **Smart-hide can react up to 250 ms later** after a window is moved or resized.
- **Titles are not throttled:** the measurement showed geometry, not titles. If a launcher retitles itself constantly, title changes would need the same treatment.
- **Not done:** making MacShell's update cheaper (only replacing the windows that changed). Unnecessary if this fixes the stutter.

## Test plan (Plasma)

1. Before updating, if not already done: run the launchers and note the stutter.
2. Update, restart MacShell (`systemctl --user restart macshell`). Run the same launchers outside gamescope → MacShell animations (Dock magnification, opening a popover) stay smooth.
3. Measure with the counting script from the diagnosis: `sleep 32 | timeout 30 <bridge> | python3 ~/bridge-churn.py` while the launchers run → at most about 120 window-list updates in 30 s (4 a second), down from hundreds.
4. Drag a window over the Dock with smart-hide on → the Dock still hides and comes back; a lag of up to a quarter second is expected.
5. Make a window fullscreen and back → MacShell still notices (Game Mode auto with a fullscreen game; the video wallpaper pauses if used).
6. Minimize a window with Magic Lamp → it still flies into its Dock icon, also after moving the window to another screen first.
