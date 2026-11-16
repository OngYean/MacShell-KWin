# Click the desktop to peek at it (2026-11-16)

`AGENTS.md` remains the authority. This file covers one request the user sent on 2026-11-16 for branch `pending-test`.

**State: written and pushed to `pending-test` on 2026-11-16 as a `wip` commit. Nothing has run in Plasma.**

| ID | Request (user's words) | Status |
| --- | --- | --- |
| F17 | Add an option in settings that messages KWin to toggle peeking at desktop when MacShell's background is clicked. | written, untested |

## What was checked

- KWin 6.8.2's source. The bridge's existing `showDesktop` command calls `PlasmaWindowManagement::setShowingDesktop`, which ends in `Workspace::setShowingDesktop` (`wayland_server.cpp`), the call behind the Peek at Desktop shortcut. It hides only windows for which `breaksShowingDesktop` is true: not docks, not desktop windows. Under KWin every MacShell layer window has the scope `dock` (`Compositor.layerNamespace`) and the wallpaper has `desktop`, so the bar, Dock, desktop icons, widgets and wallpaper stay. Activating a hidden window ends the peek (`activation.cpp`).
- `qmllint` 6.12 (syntax only) on the five changed QML files: no new errors, and no new kinds of finding except two more `unqualified access` warnings in `Wallpaper.qml` of the kind it already had.
- The node tests and `fake-bridge.py --selftest` still pass. No new test: the change is one toggle.
- Not checked: anything at run time.

## How it works

- `KWinBackend.qml` keeps `showingDesktop` from the bridge's `windows` message (the bridge already sent it, and sends a new message when KWin changes it) and has the capability `showDesktop`. `Compositor.qml` passes both on. Nothing changed in the bridge.
- `MacDock.qml`: setting `desktopPeek` (saved in `~/.config/macdock/settings.json`, off by default) and `peekDesktop()`, which calls `comp.showDesktop(!comp.showingDesktop)`. The switch is Settings → Desktop & Dock → Desktop → "Click wallpaper to reveal desktop"; it is hidden where the compositor cannot do it (Hyprland).
- `Desktop.qml`: a left click on the empty desktop (no drag, no icon, no Ctrl or Shift, not on a widget, and not a click that just closed a popover or menu) calls `peekDesktop()`.
- `Wallpaper.qml` (replace mode): with Desktop Icons off there is no Desktop layer, so the wallpaper window takes the click itself, and only then.

## Limits

- In coexist mode with Desktop Icons off, the desktop under the windows is `plasmashell`'s and MacShell never sees the click.
- A double click on the empty desktop toggles twice.
- The animation is whichever KWin effect handles Peek at Desktop (Window Aperture by default); MacShell adds none.

## Test (Plasma)

1. Settings → Desktop & Dock → Desktop: "Click wallpaper to reveal desktop" is there and off. With it off, a click on the empty desktop does what it did before (clears the selection, nothing else).
2. Turn it on, open two or three windows, click an empty part of the desktop: the windows move aside. The menu bar, Dock, desktop icons and widgets stay where they are.
3. Click the empty desktop again: the windows come back and the one that was active is active again.
4. Peek, then click an app's Dock icon: the peek ends and that window is in front.
5. Peek with Meta+D (KWin's own shortcut), then click the desktop: the windows come back (MacShell follows KWin's state).
6. With the option on: clicking an icon, dragging a selection rectangle, right-clicking, and clicking a widget do not peek. With a Control Center or a menu open, a click on the desktop closes it and does not peek.
7. Replace mode (`macshell-session start`), Desktop Icons off: a click on the wallpaper peeks. Turn the option off: the wallpaper takes no clicks again.
8. Restart MacShell: the option is still on.
