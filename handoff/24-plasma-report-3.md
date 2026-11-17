# Six items from the user's Plasma test of 2026-11-17

`AGENTS.md` remains the authority. This file covers the six items the user sent on 2026-11-17 for branch `pending-test`, after running the branch in Plasma. One of them came with a picture of macOS's fan stack.

**State: written and pushed to `pending-test` on 2026-11-17 as `wip` commits. None of the six changes has run in Plasma or in Quickshell.**

The report also tells us what already works in Plasma, which no brief could say before: MacLock shows as KDE's lock screen, Magic Lamp minimizes into the Dock and restores from a window's own cell, a pinned folder opens its stack, and Recent Items opens.

| ID | Request (user's words, shortened) | Status |
| --- | --- | --- |
| F20 | MacShell's lock screen should appear on the main screen of the user's choice in MacShell's settings when several are present; otherwise the built-in screen. | written, untested |
| B15 | For a short moment Plasma's lock screen is visible before MacShell's shows up. Sync MacShell's wallpaper to KWin's lock to work around that. | written, untested |
| B16 | Restoring a minimized window with Magic Lamp starts from the minimized preview, but near the end the effect switches its source to the app's icon on the left. | written, untested |
| F21 | Opening a pinned folder from the Dock is slow, and the style should match the picture (macOS's fan). | written, untested |
| F22 | Recent Items' submenu should follow the submenu preference: open in place, or expand into another menu. | written, untested |
| F23 | Change the battery's colour to white, matching the other items of the top bar. | written, untested |

## What was checked

- `sh nix/test-lock-screen.sh` passes on the macOS dev box (Qt 6.12 from the PySide6 wheel), with two new checks: the display chosen in MacShell gets the full layout while it is connected; without it the built-in panel does, and without that the first screen.
- `sh nix/test-lock-wallpaper.sh` passes (new, added to CI). It runs `MacShell/assets/lock-wallpaper.sh` against stand-ins for `kreadconfig6` and `kwriteconfig6`: two keys are written when MacLock is named by the variable or by `plasmashellrc`; nothing is written for Plasma's own lock screen, when `plasmashellrc` names another shell, or for a picture that is gone.
- `node nix/test-dock-folders.js` and `node nix/test-apple-menu.js` pass unchanged. Ten listings of a folder with 15 files and a subfolder took 3.46 s with the old `list-folder.sh` and 0.86 s with the new one on the dev box (macOS). The listing was also checked with `file` missing: the types are empty and folders are still marked.
- The fan was lifted out of `MacDock.qml` and run offscreen with stand-in data (five items and "Open in File Manager"): the rows sit in an arc that leans right, a long name is cut in its middle, the arrow button is drawn. Icons, hover and clicks were not part of that run.
- `qmllint` 6.12 (syntax only) on `MacBar.qml`, `MacDock.qml`, `LockState.qml` and `kde/lockscreen/LockScreen.qml`: the same findings as before the change (`MacDock.qml` keeps its two old `duplicated id` errors).
- KDE's 6.8.2 sources were read for B15 and B16 (below). `plasma-apply-wallpaperimage.cpp`, the image wallpaper's `main.xml` and `kscreenlockersettings.kcfg` give the two keys that are written.
- **Not checked:** anything at run time; `shellcheck` on the two new scripts (not installed here; they are in the CI list); the Hyprland side.

## F20: the lock screen's main display

- The setting already existed: Settings → Displays → Main display, saved as `primary` in `~/.config/macshell/displays.json`. Its subtitle already said "the lock screen controls go here", but under KDE the full layout went on the first screen Qt lists.
- `LockState.qml` now reads that file with its other lookups (`mainScreen`) and `primaryOf(screens)` picks: that display while it is connected, else a screen named `eDP…`, `LVDS…` or `DSI…` (the built-in panel), else the first. `kde/lockscreen/LockScreen.qml` uses it for `isPrimary`.
- Not done: Hyprland (`MacLock/shell.qml`) still uses the focused monitor, as upstream does. There is no Hyprland machine to test on.

## B15: KDE's lock wallpaper under MacLock

- Cause, from `kscreenlocker`'s `greeterapp.cpp` (v6.8.2, lines 360 to 396): the greeter loads KDE's own lock wallpaper (the plugin and picture in `kscreenlockerrc`) and parents it to the lock screen's root item at `z = -1000`. MacLock starts at opacity 0 and fades in once its wallpaper is decoded, so KDE's wallpaper is what shows until then. [`18`](18-lock-screen-tests.md) said the view was black behind the screen; that was wrong.
- Fix, as the user asked: `MacShell/assets/lock-wallpaper.sh <picture>` writes `[Greeter] WallpaperPlugin=org.kde.image` and `[Greeter][Wallpaper][org.kde.image][General] Image=file://<picture>` with `kwriteconfig6`, the way `plasma-apply-wallpaperimage` writes the desktop's. `MacBar.qml` runs it whenever `wallpaperPath` changes, which includes startup. The greeter is a new process at every lock, so nothing needs reloading.
- It writes only while MacLock is KDE's lock screen: `plasmashellrc`'s `ShellPackage`, else `PLASMA_DEFAULT_SHELL`, must be `com.macshell.lock`. Otherwise the user's own lock wallpaper would be overwritten for nothing.
- Limits: the user's choice under System Settings → Screen Locking → Appearance is overwritten while the option is on, and is not put back when it is turned off. With a video wallpaper KDE gets the still picture. Next to `plasmashell` with no pick in MacShell nothing is written. The fill mode is not written (KDE's default, scaled and cropped, is what MacLock uses).

## B16: Magic Lamp switching to the app's icon

- Cause: KWin's Magic Lamp reads the window's icon rectangle on every frame (`magiclamp.cpp:84`). A restored window's own cell leaves the Dock at once, the Dock recomputed the targets and sent the app's icon 250 ms later, in the middle of an animation that lasts 250 ms times KDE's animation speed.
- Fix: after any minimize or restore (`minimizedRev`), the Dock waits 1.2 s before it sends targets, longer than the animation at KDE's slowest speed setting (1 s). KWin keeps the rectangle it has until then.
- Consequence: a window being minimized goes into its app's icon for the whole animation (before, it could switch to its new cell part-way). Its own cell is the target from 1.2 s later, so a restore comes out of the cell. A window restored within 1.2 s of being minimized comes out of the app's icon.

## F21: the folder stack as a fan, and its delay

- **Delay.** `list-folder.sh` started `file` once per item (15 processes). It now starts it once for all of them and pairs the lines with the names. Its output format and `DockFolders.js` are unchanged.
- **Fan.** The stack is no longer drawn in the menu's bubble. `ui.openMenu(cell, model, true)` sets `ui.menuFan`, and a new `fan` item in `MacDock.qml` draws the model: one row per item, the newest nearest the Dock, "Open in File Manager" (kind `open`) on top as a round grey button with an arrow. A row is a dark pill with the name, then the icon; each row sits a little further right and leans a little more than the one below. The rows spring up from the folder's icon when the fan opens.
- Opening, closing (a click anywhere else), following the icon while the Dock magnifies and "one popover at a time" are still the menu's. The bubble went back to a plain `Column`; its tile code is gone.
- Limits: the fan has no blur behind its pills (they are 86 % opaque), so "Dock labels and menu" set to KWin's blur does not apply to it. It shows as many items as fit in the room the Dock's window keeps for menus: 5 at the default Dock size (52), 8 at the smallest, 1 at the largest; the grid showed 15. No "N more" count. The pills are dark in light mode too, as on macOS.

## F22: Recent Items and Force Quit beside the menu

- With Settings → Menu Bar → "Submenus open to the side" on, the two lists open in the panel the global menu's submenus use (the `subRep` Repeater in `MacBar.qml`), beside their row: 200 ms after the pointer rests on the row, or on a click. Moving to another row of the menu closes the panel. With the setting off they open in place, as before.
- `ui.appleEnter(id, rowY)` is the one way in and out for both modes. The panel's rows are `appleSubModel(id)` without its first two rows (the "‹" row and its separator). The panel's delegate gained what those rows need: a glyph, the translated headings, and Force Quit's second click.

## F23: the battery in the menu bar

- The outline and the cap were drawn in the bar's secondary colour (62 % white on a dark bar) and the fill was green while charging. All three now use the bar's text colour. The fill is red only at 15 % or less while not charging. The charging bolt is unchanged.
- This is a guess at what "white" covers: the user did not say whether the grey outline or the green fill was meant. Both were changed.

## Test (Plasma, after a rebuild)

**Lock screen (F20, B15), with `programs.macshell.lockScreen = true`:**

1. `kreadconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image` prints `file://` and the wallpaper picked in MacShell. Pick another wallpaper in MacShell and run it again: it follows.
2. Lock (Meta+L). Expected: no other picture or lock screen shows before MacLock; the screen fades in over the same wallpaper. If something still flashes, say what it shows (a picture, a clock, a password field).
3. Two screens: choose the external one under Settings → Displays → Main display, lock: clock, Now Playing and the password field are on it, the laptop's panel shows wallpaper and clock. Choose the laptop's panel, lock: the other way round.
4. Unplug the chosen external screen (or choose one, then lock with it unplugged): the full layout is on the laptop's panel.
5. `programs.macshell.lockScreen = false` on a test profile, or simply check after test 1: with the option off, changing MacShell's wallpaper must not change the value printed in test 1.

**Magic Lamp (B16), with "Show window previews" on:**

6. Minimize a window, wait two seconds, restore it by clicking its cell next to the Trash. Expected: it comes out of the cell for the whole animation. Repeat with Alt+Tab.
7. Set System Settings → Animation speed to its slowest and repeat test 6.
8. Minimize a window and watch where it goes: its app's icon, for the whole animation, with no switch part-way.

**Folder stack (F21):**

9. Click a pinned folder. Expected: the fan of the picture: names in dark pills left of the icons, rising in an arc that leans right, "Open in File Manager" with a round arrow button on top. Note how long it takes to appear compared with before.
10. Hover a row: its pill turns the accent colour. Click a file: it opens and the fan closes. Click "Open in File Manager": Dolphin opens the folder. Click anywhere else: the fan closes.
11. A folder with one item, and an empty folder: the fan has that item and the button, or the button alone.
12. Right-click any Dock icon: its menu looks and works as before (the bubble's layout code changed back to a column).
13. With the fan open, move the pointer along the Dock: the fan stays attached to the folder's icon as the icons magnify.

**Apple menu (F22):**

14. Settings → Menu Bar → "Submenus open to the side" on. Open the top-left menu and rest the pointer on Recent Items: a panel opens beside the row with Applications and Documents. Move into it and click an application: it starts. Move to another row of the menu: the panel closes.
15. Same with Force Quit: the first click on an application turns the row red ("Click again to confirm"), the second ends it.
16. The setting off: both lists replace the menu under a "‹" row, as before.

**Battery (F23):**

17. On battery and on the charger: outline, cap and fill are white (dark on a light bar), with the bolt while charging. If the part you meant was something else, say which.
