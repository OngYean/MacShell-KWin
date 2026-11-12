# Widgets on any screen, and a title and menu per screen (2026-11-12)

`AGENTS.md` remains the authority. This file continues [`16-blur-panels-report.md`](16-blur-panels-report.md) with one bug and one request the user sent on 2026-11-12 for branch `pending-test`.

**State: committed on `pending-test` as `wip` commits and pushed on 2026-11-12. Nothing has run in Plasma, and nothing here has been seen on two screens.**

| ID | Report or request (user's words) | Status |
| --- | --- | --- |
| B12 | Currently unable to add widgets to other screens. | fix written |
| F12 | Make the global menu and window title show per screen, instead of shared universally. | written |

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
