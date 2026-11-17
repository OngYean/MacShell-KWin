# Folders in the Dock, opening as a stack (2026-11-16)

`AGENTS.md` remains the authority. This file covers one request the user sent on 2026-11-16 for branch `pending-test`.

**State: written and pushed to `pending-test` on 2026-11-16 as `wip` commits. Nothing has run in Plasma, in Quickshell or in Dolphin.**

| ID | Request (user's words) | Status |
| --- | --- | --- |
| F16 | Allows pinning any folder to the right side of the dock (on the left of trash can), the pinning can be done via this shell's settings, or by a dolphin kservice entry. Clicking on the pinned folder should make it expand its child items just like on mac. | written, untested |

## What was checked

- `node nix/test-dock-folders.js` passes on macOS (new, added to the CI workflow). It checks `MacShell/DockFolders.js` (the pin list and the tiles) and runs `MacShell/assets/list-folder.sh` on a folder it makes: newest first, hidden files left out, the item limit, a folder that is gone.
- `qmllint` 6.12 (PySide6 wheel, syntax only) on `MacDock.qml`: no new errors compared with `15217f1`. The new findings are the usual unresolved Quickshell types (`IpcHandler`, `Process`, `StdioCollector`). The two old `duplicated id` errors remain.
- The menu's `Column` became a `Flow`. A stand-in QML file with the same sizing rules was run offscreen (Qt 6.12): seven tiles lay out five to a row, the separator and the last row take the full width, and a menu without tiles has the heights it had as a `Column`.
- KIO's source (`master`) was read for the service menu: it loads `kio/servicemenus/*.desktop` from every data directory (`kfileitemactions.cpp`, `serviceMenuFilePaths`) and runs an entry that is owned by root or executable (`KDesktopFile::isAuthorizedDesktopFile`). Not re-checked against the KDE Frameworks version of Plasma 6.8.2.
- Not checked: `shellcheck` on `list-folder.sh` (not installed here; it is in the CI list), the Nix build, and everything at run time.

## How it works

- **Storage.** A pinned folder is an entry of `~/.config/macdock/pinned.json` that starts with `/`, beside the app ids. No new file and no new setting. The original MacShell ignores such an entry (it is not an application id). "Reset Dock Items" in Settings removes the folders too.
- **Dock.** `rebuild()` adds one cell per folder after "Apps" and before the Trash: `special: "folder"`, `path`, the theme's `folder` icon. Like the Trash it cannot be dragged or torn off.
- **Click.** `listFolder()` runs `assets/list-folder.sh <dir> <max>`, which prints the type and name of the newest children. `stackMenu()` turns that into the model of the Dock's existing right-click bubble: one `tile` per child, a separator, "Open in File Manager". The bubble's delegate draws a tile as an icon over a name; everything else about the bubble (tail, position, closing, blur, one popover at a time) is the menu's. Middle click and "Open" open the folder in the file manager.
- **Icons.** A child's icon is the theme icon of its type (`application/pdf` → `application-pdf`, then `application-x-generic`, then `text-x-generic`). PNG, JPEG, GIF, WebP, BMP and SVG files show themselves. `file` supplies the type; the Nix wrapper now puts it on `PATH`. Without it every file gets the generic icon.
- **Opening a child.** Through `Desktop.openItem()`, so it behaves like a double-click on the desktop: folders in the file manager, `.desktop` files as applications, other files in their default application.
- **Settings.** Applications → Folders in Dock: the pinned folders with Remove, and "Add a folder" → Choose… (kdialog, zenity or yad).
- **Dolphin.** `nix/macshell-pin-folder.desktop` is a KIO service menu for one local folder. The `macshell` package installs it to `share/kio/servicemenus/` with `Exec` pointing at the packaged `macshell`. It runs `macshell ipc call dock pinFolder <path>`, a new IPC target in `MacDock.qml`.

## Decisions and limits

- **From 2026-11-17 the stack is a fan, not the grid described here**, and the listing runs `file` once instead of once per item: see [`24`](24-plasma-report-3.md). Tests 2, 6 and 13 below describe the grid and are replaced there.
- Grid only. macOS also has a fan and a list; neither was written.
- The grid has five columns and as many rows as fit in the 300 px the Dock's window already keeps for menus: 15 items at the default Dock size, 5 at the largest, 20 at the smallest. The rest are reached with "Open in File Manager". Making the Dock's window taller for a bigger grid was not done (it would cost memory on every screen, see [`19`](19-memory-report.md)).
- Sorted newest first by modification time, for every folder. macOS sorts Downloads by date added and other folders by name.
- The folder's cell always has the plain `folder` icon, not `folder-download` and the like, and not a pile of its contents.
- The folder is read when it is clicked. Nothing watches it, and nothing is read while the stack is closed.
- Dolphin's entry does nothing when MacShell is not running, and shows no message.
- No drag and drop onto the folder, and the folders cannot be reordered except by editing `pinned.json`.
- The new Settings and menu texts are English only (no `ru` or `es` entries).

## Test (Plasma, after `home-manager switch` or a rebuild)

1. Settings → Applications → Folders in Dock → Choose…, pick `~/Downloads`. A folder icon appears between "Apps" and the Trash, its hover label says "Downloads", and the folder is listed in Settings with its path.
2. Click it. A glass bubble opens above it with a grid of the newest items: icons for files, the picture itself for images, a folder icon for subfolders, names underneath, "Open in File Manager" at the bottom. Note whether the bubble fits on screen at your Dock size and whether three rows show at the default size.
3. Hover a tile: it highlights. Click a file: it opens in its default application and the bubble closes. Click a subfolder: Dolphin opens it. Click "Open in File Manager": Dolphin opens the folder.
4. Click the folder, then click anywhere else, or the folder again: the bubble closes.
5. Middle-click the folder: Dolphin opens it without a stack.
6. Right-click an application icon: its menu looks and behaves as before (this menu changed from a Column to a Flow).
7. In Dolphin, right-click a folder: "Pin to MacShell Dock" is in the menu (it may sit under a submenu of actions). Choose it: the folder appears in the Dock. Choosing it again changes nothing. If the entry is missing, check `ls ~/.nix-profile/share/kio/servicemenus/ /etc/profiles/per-user/$USER/share/kio/servicemenus/ 2>/dev/null`.
8. `macshell ipc call dock pinFolder "/tmp/a folder with spaces"` (create it first): it is pinned under its own name.
9. Right-click a pinned folder → Remove from Dock: it goes. Remove another one from Settings.
10. Restart MacShell: the pinned folders are still there. `cat ~/.config/macdock/pinned.json` shows them as paths after the app ids.
11. Drag a pinned app to reorder it, then check the folders are still pinned.
12. Pin a folder, delete it on disk, click it: a bubble with only "Open in File Manager" opens; nothing else happens.
13. With KWin's blur chosen for "Dock labels and menu" (Settings → Appearance → Panels), open a stack: the blur is behind the whole bubble.
