# Test plan: minimizing into the Dock (KWin's Magic Lamp)

`AGENTS.md` remains the authority, and [`06-kwin-testing-guide.md`](06-kwin-testing-guide.md) has the general runbook. On 2026-11-05 the user asked for KWin's Magic Lamp to minimize windows into their place in MacShell's Dock, not towards the pointer. Branch `kwin-magic-lamp`, from `kwin-replace-wallpaper-splash`.

Written on macOS without Nix, Quickshell or Plasma. Done there:
- `clang++ -fsyntax-only -Wall -Wextra` of `kwin-bridge/main.cpp` is clean against the real Qt 6.12 and KWayland 6.8.2 headers, with a hand-written stand-in for the generated layer-shell header;
- `python3 kwin-bridge/fake-bridge.py --selftest` passes;
- the new QML JavaScript parses in Node, and the Dock's target computation gives the expected positions in a Node mock (two screens, separators, a window cell, Dock limited to one screen).

CI on `pending-test` (`3abdc32`, run `41991523455`) passes: the bridge builds with the generated layer-shell code, and against a headless KWin 6.8.2 `--check` reports `icon_anchors=1`. KWin reports the rectangle the bridge registered as KWrite's `iconGeometry`, so the anchor approach works in KWin itself. MacShell loads with no new QML diagnostics. **Not run: every check below.** The animation and multi-screen behaviour need Plasma.

## How it works

- KWin animates a minimized window into its `iconGeometry`, and without one towards the pointer (`magiclamp.cpp`). A task manager sets it with `org_kde_plasma_window.set_minimized_geometry`, relative to one of **its own** surfaces.
- MacShell's Dock surface belongs to Quickshell, so `macshell-kwin-bridge` puts an invisible 1×1 layer surface (an *anchor*) at the top-left corner of every output. It registers each window's Dock rectangle against the anchor of the screen MacShell names. Details: [`kwin-bridge/README.md`](../kwin-bridge/README.md#minimize-targets-decision-record).
- The Dock (`iconTargets` in `MacDock.qml`) sends, for every window:
  - its own window cell if the Dock shows one, else its app's icon;
  - the icon's resting place (no magnification, Dock not hidden) in that screen's logical pixels;
  - on the window's own screen, or on the one screen the Dock is limited to (Settings → Desktop & Dock → monitor).
- It is sent 250 ms after the Dock or the windows stop changing. `KWinBackend` sends only changes, and resends everything to a restarted bridge.

## 0. Before you start

1. Build or run from this branch (`nix run .#macshell` from the work tree, or install the package). The bridge must be 0.2.0: `macshell-kwin-bridge --version`.
2. System Settings → Window Management → Desktop Effects: **Magic Lamp** is on. It replaces Squash; only one minimize animation can be on.
3. `macshell-kwin-bridge --check` ends with `icon_anchors=N`, where N is the number of connected screens. **0 means the feature is off:** note the `status=` lines on stderr.

## 1. Minimize into the app icon

1. Open Dolphin (pinned or not). Minimize it with the Klassy minimize button, then with KWin's shortcut (`Meta+PgDown` by default). **Expected:** the lamp goes into Dolphin's icon in the Dock, not to the button or the pointer.
2. Restore it by clicking its Dock icon, and once with Alt+Tab. **Expected:** it comes out of the same icon.
3. Two Dolphin windows: both go into the same icon.
4. Reorder the Dock (drag an icon), change the icon size and spacing, or switch magnification off and on. Then minimize again. **Expected:** the target follows the icon's new place.
5. With the Dock set to hide automatically, minimize while it's hidden. **Expected:** the lamp ends where the icon is when the Dock shows. The Dock doesn't pop up; that is how it was built.

## 2. Window cells and the edges

1. If the Dock shows a cell per open window (next to the Trash), the window goes into **its own** cell.
2. A dialog (for example Dolphin's Properties) goes into Dolphin's icon too. Without a target of its own, KWin uses its main window's. A window the Dock doesn't list (`skipTaskbar`, or no app id) still goes towards the pointer, as before.
3. An Xwayland app (for example `xterm`, or an X11 build of an app) behaves like a Wayland one.

## 3. Several screens

1. A window on the second screen goes into the second screen's Dock. Move it to the first screen, wait a moment, then minimize. **Expected:** the first screen's Dock.
2. Limit the Dock to one monitor. **Expected:** windows on either screen go into that monitor's Dock.
3. With fractional scaling (for example 125 %) on one screen, the target is still exactly on the icon.
4. Hotplug: unplug the external screen, then minimize a window. **Expected:** the remaining Dock; `--check` shows one anchor fewer. Plug it back in. **Expected:** `icon_anchors` goes back up, and windows on it go into its Dock again.

## 4. Robustness and cost

1. Restart MacShell (`systemctl --user restart macshell`, or stop and start `macshell`). **Expected:** targets work again after a couple of seconds.
2. `pkill -f macshell-kwin-bridge`. MacShell restarts it within a second or two. **Expected:** targets work again.
3. Sleep and resume, then minimize. **Expected:** still into the Dock.
4. Hybrid graphics: the anchors use a shared-memory pixel and never EGL. With the NVIDIA GPU idle, check `cat /sys/bus/pci/devices/<nvidia>/power/runtime_status` stays `suspended` while you minimize and restore.
5. Nothing visible: no 1-pixel dot in a screen's top-left corner; clicks there still reach whatever is underneath; the anchors don't show in the Dock, Alt+Tab, Overview or the window list.
6. Running next to `plasmashell` (`macshell-session coexist`) with a Plasma task manager in a panel: KWin uses whichever registered target is nearest the window. Note which one wins; this is expected, not a bug.

## Results to report

For each numbered step: pass or fail, and what you saw. Also the `--check` line (counts only) and any `[kwin-bridge]` lines from `macshell log`. They carry status codes, never titles.
