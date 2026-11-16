# Memory use of the Quickshell process (2026-11-16)

`AGENTS.md` remains the authority. This file covers one report the user sent on 2026-11-16 for branch `pending-test`, and the three changes that followed it.

**State: written and pushed to `pending-test` on 2026-11-16 as `wip` commits. Nothing has run in Plasma, and no memory figure has been measured: every size below is arithmetic from texture dimensions.**

| ID | Report or request (user's words) | Status |
| --- | --- | --- |
| B14 | RAM usage of the Quickshell process goes as high as 700 MB+ (or is it normal?). Then: implement the cheap fixes. | three changes written, untested; the larger causes are left as they are |

## What uses the memory (read from the code, not measured)

A full-screen RGBA picture is about 16 MB at 2560×1600 and 32 MB at 4K.

| # | Cause | Where | Changed here? |
| --- | --- | --- | --- |
| 1 | The Liquid Glass backdrop of the bar and of the Dock, per screen: a screen-sized flattened texture, four edge strips, blur passes, a wallpaper texture. They stay rendered while the panel uses Stock blur. | `MacBar.qml` `backdropComp`, `MacDock.qml` `glassBackdrop` | No. A panel on KWin's blur has no backdrop (`liquidActive`, `glassPipe`). |
| 2 | Many windows that are always mapped, each its own Qt Quick scene with a render thread: bar, Dock, desktop, wallpaper, widgets, four corner windows when a corner radius is set. Twice with two screens. | `shell.qml`, `ScreenCorners.qml` | No. |
| 3 | The wallpaper decoded two or three times per screen, because the Image items asked for different sizes. | bar and Dock backdrops, `Desktop.qml`, `Wallpaper.qml`, Settings, widgets | **Yes** (change 1). |
| 4 | The bar's window was the bar plus 900 px tall, always, and screen-wide. | `MacBar.qml` `popRoom` | **Yes**, under KWin (change 3). |
| 5 | Each overlay (app switcher, wallpaper picker, level OSD, Spotlight) kept its backdrop loaded while closed. | `MacBar.qml` `swBackdrop`, `wpBackdrop`, `osdBackdrop`, `spotBackdrop` | **Yes**, under KWin (change 2). |
| 6 | With "Animated wallpaper in glass" on: one video decoder per loaded backdrop. | `LiveWall.qml` | Partly: change 2 removes the overlays' decoders while they are closed. |

**A correction to what the user was first told.** The first answer said a closed overlay window keeps its textures, so memory steps up the first time each overlay is opened. That is wrong for these windows: Quickshell destroys a layer-shell window when it is hidden (`WlrLayershell::deleteOnInvisible()` returns true, Quickshell v0.3.2), and its textures go with it. What a closed overlay did keep is cause 5: the backdrop's QML objects, which include a copy of every desktop widget and, with an animated wallpaper in the glass, a running video decoder.

Not causes: the pictures of minimized windows (256 px), the Settings panes (loaded on demand), the emoji table (72 KB).

Whether 700 MB is "normal": a QML shell that draws its own glass sits well above a plain bar, and `plasmashell` itself commonly uses a few hundred MB. Causes 1 and 2 are the design; the user can remove most of cause 1 by putting panels on KWin's blur.

## The three changes

**1. One decoded wallpaper per screen.** Qt shares a decoded picture between Image items only when they ask for the same file at the same size. `hub.wallpaperSize(screenName)` (`shell.qml`) is now the one size: physical pixels while MacShell draws the desktop itself (`Wallpaper.qml` has to be sharp), the logical size otherwise. The bar and Dock backdrops, `Desktop.qml`, `Wallpaper.qml`, the Settings window's backdrop and the five glass widgets (through a new `wallSize` property set by `WidgetVisual.qml`) all use it. Each window still uploads its own texture; this removes the extra decoded copies in RAM.

**2. Overlay backdrops load with their window (KWin).** `warmBackdrops` is true where windows are captured (Hyprland), and there nothing changes: the backdrop stays loaded so its captures are streaming when the overlay opens. Under KWin there are no captures, so the four backdrops are loaded when their window shows and destroyed when it hides.

**3. The bar's window is only as tall as what it shows (KWin).** At rest it is the bar plus 24 px. It becomes the old height (bar + 900 px) the moment something shows below the bar, and goes back 2 s after the last of it has gone. "Something below the bar" is `ui.below`: an open popover, a popover still folding away (each popover's own `visible`), the click-away area, a notification banner. Popover sizes that were computed from the window's height now use the fixed full height (`ui.tallH`), because the window only grows a frame or two after a popover starts opening. Hyprland keeps the fixed height.

## Decisions and their reasons

- **KWin only for changes 2 and 3.** The Hyprland path has no test machine, upstream chose the warm backdrops and the fixed bar height deliberately there (captures, layer animations), and the user runs KWin.
- **`ui.below` lists the popovers by their `visible`.** If one of them never reports invisible, the window simply never shrinks: the failure is "no saving", not "something clipped".
- **Two seconds before shrinking.** Long enough for every fold-away and banner exit, and it keeps the surface from being resized on every popover when several are opened in a row.
- **Not done:** unloading the bar's and the Dock's own backdrops, merging windows, or anything else in causes 1 and 2. They are the glass design, not cheap fixes.

## What was checked

- `node nix/test-wallpaper-size.js` passes (new, added to the CI workflow): `wallpaperSize()` lifted out of `shell.qml` for known, unknown and missing screens, and a check that no wallpaper Image in `MacShell/` still asks for a size of its own.
- `qmllint` 6.12 on the eleven changed QML files: no errors and no new kinds of finding compared with `caeb16e` (`WidgetVisual.qml` gains "unqualified access" warnings of the kind its neighbouring lines already have).
- The existing `node` tests still pass.
- **Not checked:** anything at run time, any memory figure, and that Qt really shares the decoded copy across these Image items (it follows from Qt's cache key, which is the file, the requested size and the fill mode's crop flag; all sites use `PreserveAspectCrop`). CI still does not run (the account is locked over billing).

## Test plan (Plasma 6.8, Wayland)

**Measure.** Before updating, and again after, each time a minute after login with nothing opened:

```sh
pid=$(systemctl --user show -p MainPID --value macshell.service)
grep -E '^(Rss|Pss|Anonymous)' /proc/$pid/smaps_rollup
ls /proc/$pid/task | wc -l          # threads: roughly one per live window
grep -c jemalloc /proc/$pid/maps    # 0 = this Quickshell build has no jemalloc, and heap fragmentation will look like a leak
```

Report both sets of numbers, the screen resolution and scale, and which panels are on Stock blur. Then, to see what is left: put every panel on KWin's blur (Settings → Appearance → Panels), restart MacShell and measure once more.

**Nothing may look different:**

1. The wallpaper on the desktop is as sharp as before, and the glass of the bar, the Dock, a menu, the Control Center, the desktop's right-click menu, the Settings window and a glass widget shows the wallpaper behind it in the right place.
2. Change the wallpaper: every one of those follows.
3. Open each popover of the bar in turn (Apple menu, an app menu with a submenu, Control Center and its Wi-Fi page, Wi-Fi, Bluetooth, volume, calendar, notification centre, a tray icon's menu, the keyboard layout menu): none is cut off at the bottom or squashed, at opening or while it folds away. Watch the first instant of opening for a cut-off or a hitch.
4. A long menu that needed scrolling before still scrolls and ends where it did.
5. With nothing open, send a notification (`notify-send test`): the banner appears whole, and leaves whole.
6. Two screens: with a popover open on one, a click on the other screen's desktop still closes it.
7. Click just below the bar with nothing open: the click reaches the window underneath.
8. Spotlight, the app switcher (Alt+Tab), the wallpaper picker and the volume OSD, each with its panel on Stock blur: the glass shows the wallpaper from the first frame (no coloured gradient flash, no see-through pane), and opening does not hitch more than before.
9. Spotlight's text colour suits what is behind it (its tone measurement used the bar window's height).
10. With "Animated wallpaper in glass" on: the video still shows in the bar's and the Dock's glass, and in Spotlight once it is open.

If test 3 or 5 shows clipping, note which item: it is missing from `ui.below` in `MacBar.qml`. If opening hitches (tests 3 and 8), say which, so the choice can be made per change.
