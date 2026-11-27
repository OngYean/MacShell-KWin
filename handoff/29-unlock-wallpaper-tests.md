# The wallpaper takes a few seconds to come back after unlocking (2026-11-27)

`AGENTS.md` remains the authority. This file covers one bug the user reported for branch `pending-test`.

**State: written as a `wip` commit on `pending-test`. The cache behaviour was checked locally with Qt 6.12 (offscreen, PySide6 wheel); not run in Plasma.**

| ID | Report (user's words) | Status |
| --- | --- | --- |
| B18 | fix an issue where wallpaper takes a few seconds to load after unlocking the session | cause found for the delay, fix written, untested in Plasma |

Applies to replace mode only (no `plasmashell`), where `MacShell/Wallpaper.qml` draws the desktop. With `plasmashell` running, Plasma draws the wallpaper and this change does nothing.

## Cause

KWin hides other windows while locked but keeps their last buffers (B5 in [`15`](15-plasma-test-report.md)), so a wallpaper window that survives the lock reappears at once. A delay therefore means the per-screen wallpaper windows were made again. `Variants { model: Quickshell.screens }` does that when the screens come back as new outputs. The cause of that recreation, which is B5, is still not known.

A new window's `Image` then decodes the photo from disk, at the screen's physical size, behind a black window. Qt's image cache doesn't save it: Qt drops a decoded picture nobody uses within about 30 s. Measured with a 6000×4000 PNG at 2880×1800, `asynchronous: true`, `PreserveAspectCrop`:

- recreated 0.2 s after the old Image went away: `Ready` at creation (cache hit);
- recreated 45 s later: `Loading` at creation, decoded again;
- recreated 45 s later with another Image still holding the same file, size and fill mode: `Ready` at creation.

## The change

`Wallpaper.qml`: when a screen's wallpaper `Image` is ready, it records its file and decode size under the screen's name (`shown`, `remember()`). An `Instantiator` outside the windows keeps one hidden `Image` per recorded screen with the same file, size and fill mode. It holds that screen's decoded picture while the window is gone, so a recreated window finds the picture in Qt's cache and shows it in the first frame.

`nix/test-wallpaper-size.js` checks that the hidden copy uses the shown Image's file, size and fill mode. If any of them differ, the copy becomes a second full-size decode.

## Decisions and limits

- **No extra memory while things work:** the copy uses the same cache key (file, size, fill mode) as the shown Image, so they share one decoded picture.
- **An unplugged screen's copy** goes the next time any screen's wallpaper finishes loading. Until then it stays in memory.
- **A screen that comes back with a different size or scale** gets a new decode size, which misses the cache and loads as before.
- **B5 itself (why the windows are made again) is not fixed.** If the bar or Dock are also slow to return, that is still B5.

## Test plan (Plasma, replace mode)

1. `systemctl --user restart macshell`, wait for the wallpaper.
2. Lock (`Meta+L`), wait at least one minute (longer than Qt's 30 s cache time), unlock → the wallpaper is there immediately, without a black screen.
3. Repeat with the screen turned off during the lock (wait for it to blank, or lock and let it sleep), and once after suspend and resume.
4. With an external monitor: same as 2. Both screens show their wallpaper immediately.
5. Pick another wallpaper in MacShell's picker, then repeat 2 → the new picture comes back immediately, not the old one.
6. Memory: `ps -o rss= -C quickshell` (or `macshell` / `qs`) before and after this update, with the same wallpaper → about the same.
7. If it still takes seconds: collect `macshell log | tail -50` right after unlocking, and note whether the bar and Dock were also empty.
