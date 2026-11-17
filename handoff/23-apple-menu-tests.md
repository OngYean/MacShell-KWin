# An arrangeable Apple menu, with Recent Items and Force Quit (2026-11-16)

`AGENTS.md` remains the authority. This file covers one request the user sent on 2026-11-16 for branch `pending-test`.

**State: written and pushed to `pending-test` on 2026-11-16 as `wip` commits. Nothing has run in Quickshell or Plasma.**

| ID | Request (user's words) | Status |
| --- | --- | --- |
| F19 | Add ability to customize top left menu items (such as custom command when clicking on certain items), and at the same time add force quit and recent items (applications and files). All these menu items should be arrangeable, including the existing ones currently. | written, untested |

## What was checked

- `node nix/test-apple-menu.js` passes (new, added to CI). It checks `MacShell/AppleMenu.js` (defaults, cleaning a saved list, moving, removing, adding, what is shown) and then lifts `appleItem`, `runningApps` and `appleSubModel` out of `MacBar.qml` and runs them with stand-in windows, desktop entries and recent files: a command on a built-in item runs instead of it, Shut Down keeps its second click, Force Quit groups an app's windows and kills all their processes, Recent Items lists applications that still exist and files but not folders.
- `qmllint` 6.12 (syntax only) on `MacBar.qml` and `MacDock.qml`: the same findings as before the change (`MacDock.qml` keeps its two old `duplicated id` errors).
- Not checked: anything at run time. In particular the editor in Settings (typing into the fields, the arrow buttons) has only been read, never run.

## How it works

- **The list.** `appleMenuItems` in `~/.config/macbar/settings.json`: an ordered list of `{ id, label, command }`. `id` is a built-in item (`about`, `settings`, `recent`, `forcequit`, `sleep`, `restart`, `shutdown`, `lock`, `logout`), `sep` or `custom`. No key in the file means the default menu, which is the old menu in macOS order plus Recent Items and Force Quit. `AppleMenu.js` holds the list logic; `AppleMenu.clean()` is applied wherever the list is read, so a hand-edited file cannot break the menu.
- **The menu** (`MacBar.qml`, `menuModelFor("apple")`): one row per entry, built by `appleItem()`. A non-empty `command` on a built-in item replaces its action with `sh -c <command>`; items that asked for a second click still do. Separators at either end or doubled are not shown, nor is a custom item without a name. With nothing left to show, the menu holds System Settings… alone.
- **Recent Items and Force Quit** open inside the Apple menu's popover under a "‹" row, like a global-menu submenu without "Submenus open to the side" (`ui.appleSub`, `appleSubModel()`).
  - Recent applications: `recentApps`, the ids of the last eight applications started through `runEntry()` (the Dock and Spotlight both use it), saved in the bar's settings. Recent files: the existing `assets/recent-files.sh` list that Spotlight's Files button uses, files only, eight of them, loaded when the submenu opens.
  - Force Quit: one row per open application (KWin: the bridge's windows; Hyprland: its toplevels), without MacShell's own windows. The first click arms the row, the second runs `kill -9` on the processes of all that application's windows.
- **Settings → Menu Bar → Apple Menu Items** (`MacDock.qml`): a row per entry with ↑, ↓ and ✕, a command field on every item, a name field on custom items; below it Add Custom Item, Add Separator, a button per built-in item that was removed, and Reset. A new text-field component, `SField`.

## Limits

- Recent applications are only those started from MacShell. Ones started from a terminal, KRunner or a file association are not listed, and nothing clears the list.
- Recent Items and Force Quit always open in place, also with "Submenus open to the side" on. **Changed on 2026-11-17:** they now follow that setting, see [`24`](24-plasma-report-3.md).
- A built-in item keeps its own name; only custom items are named.
- Force Quit kills by the process id KWin reports for a window. For an app whose windows belong to a shared process (some Flatpak or single-process suites) that ends more than the one window's app.
- The glyphs of the two new items reuse existing drawings (a stack for Recent Items, a cross for Force Quit). Custom items have none.
- The new texts are English only.

## Test

1. Open the top-left menu: About, System Settings, Recent Items, Force Quit, Sleep, Restart, Shut Down, Lock Screen, Log Out, with separators between the groups. The old items do what they did.
2. Start two applications from the Dock or Spotlight and save a file somewhere under Documents. Recent Items → the list replaces the menu: "‹ Recent Items", Applications (the two, newest first), Documents (the file near the top). Click an application: it starts. Click a file: it opens. "‹" goes back to the menu.
3. Force Quit → the open applications with their icons, MacShell not among them. Click one: the row turns red and says "Click again to confirm". Click again: the application is gone. Move the pointer away after the first click: nothing happens.
4. Settings → Menu Bar → Apple Menu Items. Press ↓ on About This Linux a few times, reopen the menu: it moved. Press ✕ on Sleep: gone from the menu, and a "+ Sleep" button appears under the list; press it: Sleep is back, at the end.
5. Type `kdialog --msgbox hello` (or any harmless command) next to Lock Screen, then choose Lock Screen in the menu: the command runs and the screen does not lock. Clear the field: it locks again. While typing, the field must keep the keyboard focus and the cursor its place.
6. Add Custom Item: a row named "New Item" appears. Give it a name and a command, choose it in the menu: the command runs. Clear its name: it disappears from the menu but stays in Settings.
7. Add Separator twice and move both to the top: the menu shows no separator at its top and no double line.
8. Restart MacShell: the arrangement, the custom item and the recent applications are still there. Reset: the default menu is back.
9. Remove every item: the menu shows System Settings… alone, so the editor can still be reached.
