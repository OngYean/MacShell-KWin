# Widgets on any screen, a title and menu per screen, one popover on all screens (2026-11-12, 2026-11-13)

`AGENTS.md` remains the authority. This file continues [`16-blur-panels-report.md`](16-blur-panels-report.md) with one bug and one request the user sent on 2026-11-12 for branch `pending-test`.

**State: committed on `pending-test` as `wip` commits and pushed on 2026-11-12 (B12, F12) and 2026-11-13 (F13). Nothing has run in Plasma, and nothing here has been seen on two screens.**

| ID | Report or request (user's words) | Status |
| --- | --- | --- |
| B12 | Currently unable to add widgets to other screens. | fix written |
| F12 | Make the global menu and window title show per screen, instead of shared universally. | written |
| F13 | (2026-11-13) Treat extended screens as one contiguous working area: opening the Control Center on screen 2 should close the one that is open on screen 1. | written |

## What was checked

- `qmllint` 6.12 (PySide6 wheel, syntax only) on `MacWidgets.qml`, `MacBar.qml`, `Desktop.qml`, `WidgetVisual.qml`, `MacDock.qml`: no errors and no new kinds of finding compared with `3f609ec` (`MacDock.qml` keeps its two old `duplicated id` errors).
- `node nix/test-widget-screens.js` passes (new, added to the CI workflow). It lifts the top-level functions out of `MacWidgets.qml` and runs the per-screen grid against two stand-in screens: where a new widget goes, no blocking between screens, Player rectangles per screen, dropping onto another screen, an unplugged screen.
- Not checked: anything at run time. CI has not built anything since `3a1e8a9` (see [`16`](16-blur-panels-report.md)).

## B12: widgets on any screen

**Cause.** Upstream design, not a regression: `MacWidgets.qml` created its layer window for `Quickshell.screens[0]` only, and the grid, the overlap test, the Player click regions, the desktop icons' "keep clear of widgets" rule and the bar's glass backdrop all assumed that screen.

**Change.**
- Every widget has a screen: role `wscreen`, saved as `screen` in `~/.config/macwidgets/settings.json`. An entry without it (every existing one) means "the first screen", so existing layouts load unchanged.
- One layer window per screen that holds widgets; every screen while editing. A screen without widgets gets no window outside edit mode.
- A new widget goes on the screen in use (`focusedScreenName` of the compositor backend). When "+" is clicked in Settings, that is the screen the Settings window is on. If that screen's grid is full, nothing is added (as before on a full first screen).
- In edit mode a widget can be dragged past the edge of its screen and dropped on another one; it snaps to the nearest free slot there. The old clamp that kept a dragged widget inside its screen is gone.
- The widgets of a screen that is not connected are neither shown nor re-snapped; they return when the screen does.
- `Desktop.qml` (icon layout, Player click-through) and the bar's glass backdrop in `MacBar.qml` use the widget's screen.
- Settings → Widgets → Arrange widgets says where a new widget goes, when there is more than one screen.

**Decisions.** The target screen is taken from focus because it needs no new setting; a screen picker in Settings was not added. Hidden rather than moved to the first screen when a monitor is unplugged: a docked laptop keeps its layout.

**Test (two screens).**
1. Existing widgets are where they were, on the first screen.
2. Move the Settings window to the second screen, Settings → Widgets, add a Clock: it appears on the second screen. Move Settings back, add another: first screen.
3. Edit on Desktop: the grid shows on both screens. Drag a widget from one screen across the edge onto the other and release: it lands on the nearest free cell of that screen. If it snaps back to its old screen instead, note that (the pointer position past the window edge was not reported during the drag).
4. A Player widget on the second screen: its buttons work with editing off; desktop icons on that screen keep clear of the widgets.
5. Unplug the second screen: its widgets vanish and the first screen's stay put. Plug it back in: they return in the same places.
6. Restart MacShell: every widget is on the same screen as before.
7. One screen only: adding, moving, resizing and removing behave as before.

## F12: one title and menu per screen

**Before.** Every screen's bar showed the active window's name and menus.

**Change (KWin only; Hyprland keeps the shared title).** `MacBar.qml` remembers, per screen, the window that was last active on it (`screenWinIds`), and each bar asks `barTlFor(<its screen>)`:
- the screen with the active window: that window, with its real menus (or the generic ones), as before;
- another screen whose remembered window is still there (same screen, current desktop, not minimized): that window's name, dimmed, with no menus. A click on the name activates the window, and the bar then shows its menus;
- any other screen: the desktop name (or the custom title, F11) with the desktop's menus. They never act on a window of another screen.

With a single screen nothing changes.

**Why only the name on the other screens.** The bridge imports one menu, the active window's, and refuses menu events for any other window. The generic File / Edit / Window items also act on the active window. Showing menus for a window that is not active would run them on the wrong window, so the first click activates, as macOS does on a display that is not in use. Importing a menu per screen would mean bridge (C++) changes that cannot be compiled on the development machine while CI is down; it is the follow-up if the user wants live menus on every screen.

**Known limits.**
- A window that has not been active since MacShell started is unknown to its screen's bar: that screen shows the desktop until the window is clicked once.
- When nothing is active (for example while Spotlight is open), the screen last in use shows the desktop name, as every screen did before.
- KWin's stacking order is not used: if the remembered window is covered by another window that was never active, the bar still names the remembered one.

**Test (two screens, global menu on).**
1. Window X active on screen 1, window Y last used on screen 2: bar 1 shows X with its menus; bar 2 shows Y's name dimmed, no menus.
2. Click Y's name on bar 2: Y becomes active, bar 2 shows Y's menus, bar 1 shows X's name dimmed.
3. Minimize or close Y, or move it to another desktop, while X is active: bar 2 shows "Desktop" (or the custom title) with File / Edit / View / Window / Help. Open each: no entry names X; "New Terminal" and "Show All" work.
4. Drag Y from screen 2 to screen 1: bar 2 falls back to the desktop, bar 1 shows Y.
5. Open the Apple menu on bar 2 while it shows a dimmed name, then move the pointer over the name: no menu opens for it.
6. While a terminal on screen 1 keeps changing its title, the names on bar 2 do not flicker and a menu open on bar 2 stays open.
7. Qt, GTK, Electron, Firefox, VS Code: the active one's real menu still appears on its own screen and nowhere else.
8. One screen only: title and menus behave as before.

## F13: one popover or menu at a time, on all screens (2026-11-13)

**Before.** Each screen's bar keeps its own open popover (`ui.pop` in `MacBar.qml`), each screen's Dock its own right-click menu (`ui.menuItem` in `MacDock.qml`) and each screen's desktop its own right-click menu (`dctx.item` in `Desktop.qml`). Nothing told one about another, so a Control Center could be open on every screen at once, and a click on another screen closed nothing.

**Change (both compositors).** The hub in `shell.qml` has `popWho` (whoever has something open, or null) and `popScreen` (that screen's name), with `popSet(who, screen)` and `popClear(who)`. Each of the three holders sets itself when it opens something, clears itself when it closes (and when its screen is unplugged), and closes its own when `popWho` becomes anyone else. Setting `popWho` to null therefore closes whatever is open.

1. **Opening closes the rest.** Covers everything a bar's `pop` holds (Apple and app menus, the tray menu, Control Center, calendar, Wi-Fi, Bluetooth, sound, keyboard layout, the notification centre, Spotlight), the Dock's right-click menu and the desktop's right-click menu. The bar sets `popWho` at the start of `onPopChanged`, so the popover elsewhere closes (and tells its app's menu so) before the new one opens.
2. **A click on another screen closes it** (the user confirmed on 2026-11-13 that the click may be used up, "just like on mac"):
   - while something is open on another screen (`ui.popElsewhere`), a bar's window takes the pointer over its whole height (the bar plus `popRoom`, 900 px) and its click-away area closes what is open. The click goes no further, as beside a popover on its own screen;
   - a press on a Dock icon closes what is open and then does its own job (activate, right-click menu, drag);
   - a press on the desktop closes what is open and then does its own job (select, right-click menu);
   - a click on an empty part of any bar closes what is open.

**Decisions.**
- One rule for screens and for parts: the rule is "anyone else", so a Dock menu also closes a Control Center on the same screen. Before, that depended on which layer happened to take the click.
- A bar's window does not widen for its own screen's Dock menu or desktop menu: it overlaps both and would take the clicks meant for their rows.
- No separate full-screen layer for catching clicks: it would have to sit under the popovers, which live in the bar's window, and KWin does not keep one layer of a level under another (see the bar-background note in `MacBar.qml`).
- The Dock's window is not widened: that would change when its hover, magnification and auto-hide react. The icons close on press instead.
- Left out: the desktop's sheets (Rename, Quick Preview and the others), which are dialogs and stay until dismissed; the window switcher, wallpaper picker and volume pop-up, which already show on one screen only; notification banners.

**Known limits.**
- On another screen, a click on a window lower than about 900 px under the bar closes nothing. A screen up to about 930 px high (logical) is covered completely; on a 1080 px one the lowest 150 px of windows are not.
- On the popover's own screen nothing changed for clicks on windows: a bar popover closes on a click in the bar's window (the top 900 px), a Dock menu on a click in the Dock's window, a desktop menu on a click on the desktop. A click on a window outside those leaves it open, as before.
- While something is open on another screen, the screen snapshots a bar takes under the pointer are paused there (otherwise the wider input area would start them).

**Checked.** `qmllint` 6.12 (syntax only) on the four files: the same 732 findings as before the change, among them `MacDock.qml`'s two old `duplicated id` errors. Nothing at run time, and never seen on two screens.

**Test (two screens).**
1. Open the Control Center on screen 1, then on screen 2: the one on screen 1 closes. The same with the calendar, Wi-Fi, an app menu and the Apple menu, in any mix.
2. Control Center open on screen 1; right-click a Dock icon on screen 2, then right-click the desktop on screen 2: each time the earlier one closes, and the new menu's rows work.
3. A global menu open on screen 1, open the Apple menu on screen 2, then go back and open the same global menu on screen 1: its entries are filled in and work (the app was told its menu closed).
4. Spotlight (`macshell ipc call spotlight toggle`) with a popover open on the other screen: the popover closes, Spotlight opens once.
5. Control Center open on screen 1. On screen 2, one at a time: click a window near the top, click an empty part of the bar, click the empty desktop, left-click a Dock icon. Each closes the Control Center. The window does not get the first click; the Dock icon still activates its app.
6. The same as 5 with a Dock right-click menu open on screen 1, and with a desktop right-click menu open on screen 1. While either is open, its own rows and the bar on screen 1 work as usual.
7. With something open on screen 1, move the pointer over screen 2's bar and Dock without clicking: tooltips, magnification and auto-hide behave as usual.
8. A Rename or Quick Preview sheet stays open when a popover opens or a click lands on either screen.
9. Unplug a screen while its Control Center is open: on the remaining screen the first click on a window near the top reaches the window (nothing is left "open").
10. One screen only: popovers behave as before, except that a Dock or desktop right-click menu now always closes an open bar popover and the other way round, and so does a press on a Dock icon or the desktop.
