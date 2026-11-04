# macshell-kwin-bridge

The KWin side of MacShell's compositor backend. `MacShell/backends/compositor/KWinBackend.qml` starts one bridge per MacShell process, reads its JSON lines on stdout, and writes commands to its stdin. It talks only to KWin and KDE services, is event-driven (no polling timers), and exits when MacShell closes the pipe.

| Source                         | Interface                                                         | Used for                                                                                        |
| ------------------------------ | ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| KWin (Wayland, KWayland 6.8.2) | `org_kde_plasma_window_management` (KWayland binds up to v18)     | windows, active window, state, geometry, desktops per window, AppMenu address, window requests  |
| KWin (D-Bus)                   | `org.kde.KWin` `/VirtualDesktopManager` `org.kde.KWin.VirtualDesktopManager` | workspaces: list, current, switch (`current` is a writable property)                            |
| KWin (D-Bus)                   | `org.kde.keyboard` `/Layouts` `org.kde.KeyboardLayouts`           | keyboard layouts (`getLayoutsList`, `getLayout`, `setLayout`, `layoutChanged`)                  |
| Applications (D-Bus)           | `com.canonical.dbusmenu` at the active window's AppMenu address   | the global menu tree (`GetLayout`, `AboutToShow`, `Event`, `LayoutUpdated`, `ItemsPropertiesUpdated`) |
| Session bus                    | name owners of `org.kde.plasmashell`, `org.freedesktop.Notifications`, `org.kde.StatusNotifierWatcher`, `org.kde.kappmenuview` | knowing which desktop services already run, so MacShell never starts duplicates                 |

## Why this interface (decision record)

The global menu needs the **active window's AppMenu service and object path**. In KWin 6.8.2 that address is only exposed through `org_kde_plasma_window_management`:

- KWin scripting cannot see it: `Window::applicationMenuServiceName()` / `applicationMenuObjectPath()` are plain getters, not `Q_PROPERTY`s (`kwin/src/window.h` at `v6.8.2`); only `hasApplicationMenu` is scriptable.
- `org.kde.KWin.getWindowInfo()` does not include it.
- Quickshell's `ToplevelManager` needs `wlr-foreign-toplevel-management`, which KWin does not implement, so it lists no windows under KWin.

Plasma's own task manager and Global Menu applet read the same protocol. In KWin 6.8.2, `wayland_server.cpp` restricts it only for **sandboxed** clients (Flatpak / security-context), so this unsandboxed helper may bind it. The XML still describes it as a desktop-shell implementation detail, which is why its use is fenced:

- **Isolation:** only this helper binds it. QML never sees the AppMenu address, only a `hasAppMenu` flag and the decoded menu tree.
- **Version coupling:** KWayland is released with Plasma, and nixpkgs updates the two together. The bridge logs `status=unsupported` and keeps serving workspaces and keyboard layouts when the global is missing. The QML then reports `windows`/`globalMenu` as unsupported instead of guessing.
- **Data handling:** window titles and menu labels travel only through the parent pipe. stderr carries status codes only, and `--check` prints counts only.
- **Input validation:** commands are capped at 16 KiB per line, unknown commands are dropped, window ids must be known windows, desktop ids must be known desktops, and layout indexes must be in range. Menu events must name the window whose menu is shown; that window must still be active with the same address, and the item must exist in the current tree. `clicked` is only allowed on enabled, visible leaf items; `opened`/`closed`/`AboutToShow` only on submenus.
- **Application data is untrusted:** menu decoding checks D-Bus types before reading, limits depth to 12 and size to 5000 items, and drops malformed nodes.

Alternatives considered:
- A KWin script with a D-Bus relay can't reach the AppMenu address, and loading code into the compositor needs cleanup after crashes.
- `kdotool` loads one script per command, which is too heavy for continuous state.
- Plasma's applet works, but it only renders inside plasmashell.

## Global menu prerequisites (`--global-menu`)

Qt and GTK apps export a D-Bus menu only while `com.canonical.AppMenu.Registrar` exists. kded's appmenu module runs that registrar only while some menu view owns `org.kde.kappmenuview` (`plasma-workspace/appmenu/appmenu.cpp`). Plasma's Global Menu applet owns that name when it is in a panel. With `--global-menu` the bridge registers it the same way: `QueueService` plus `DontAllowReplacement`, exactly like the applet. Whichever comes first owns it and the other queues behind it, so the menus survive when plasmashell (and its applet) is stopped. Qt checks for the registrar once per process, so **apps started before a menu view existed keep their in-window menu bar until restarted**.

Menu events are sent the way KDE's `DBusMenuImporter` sends them: `Event(id, name, QDBusVariant(QString()), 0u)`, with `AboutToShow` + `opened` when a menu opens and `closed` when it goes away. Labels have their `_` mnemonic markers removed. Shortcuts are passed through as key lists (`[["Control","S"]]`). `icon` is the item's `icon-name`, or else its `icon-data` PNG (what Qt sends for icons without a theme name) as a `data:image/png;base64,` URL, at most 16 KiB per item and 1 MiB per menu; larger ones are dropped.

## Messages

One JSON object per line.

**Bridge → MacShell**

| `type`       | Fields                                                                                                                                       |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `hello`      | `protocol` (1), `bridge` (version), `windowManagement` (`available` / `unsupported`), `advertisedVersion`, `appMenuProtocol`, `globalMenu`, `dbus` |
| `windows`    | `windows[]` { `id`, `appId`, `title`, `pid`, `resourceName`, `active`, `minimized`, `maximized`, `fullscreen`, `keepAbove`, `onAllDesktops`, `demandsAttention`, `skipTaskbar`, `skipSwitcher`, `closeable`, `minimizeable`, `maximizeable`, `fullscreenable`, `x`, `y`, `width`, `height`, `desktops[]`, `parent`, `hasAppMenu` }, `activeId`, `stacking[]`, `showingDesktop` |
| `workspaces` | `available`, `current` (desktop id), `rows`, `desktops[]` { `id`, `name`, `position` }                                                      |
| `keyboard`   | `available`, `current` (index), `layouts[]` { `short`, `display`, `name` }                                                                    |
| `menu`       | `status` (`ok` / `loading` / `none` / `error` / `unsupported`), `windowId`, `appId`, `revision`, `items[]` { `id`, `label`, `visible`, `enabled`, `separator`, `submenu`, `toggle` (`""` / `checkmark` / `radio`), `toggleState`, `icon`, `shortcut`, `children[]` } |
| `session`    | `plasmashell`, `notifications`, `trayWatcher`, `menuView`: `none` / `self` (MacShell) / `bridge` / `other`                                    |

`windows` is sent (debounced by 25 ms, and only when it changed) on any window change. It lists only windows past their initial state.

**MacShell → bridge**

| `cmd`                                                                                                                     | Fields                                         |
| ------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| `activate`, `close`, `minimize`, `unminimize`, `toggleMinimize`, `toggleMaximize`, `toggleFullscreen`, `toggleKeepAbove`   | `id`                                           |
| `moveToDesktop`                                                                                                           | `id`, `desktop`                                |
| `setDesktop`                                                                                                              | `desktop`                                      |
| `showDesktop`                                                                                                             | `on`                                           |
| `setKeyboardLayout`                                                                                                       | `index`                                        |
| `menuEvent`                                                                                                               | `windowId`, `id`, `event` (`clicked` / `opened` / `closed`) |
| `menuAboutToShow`                                                                                                         | `windowId`, `id`                               |

## Build and diagnose

```sh
nix build .#macshell-kwin-bridge
nix run .#kwin-bridge -- --check                 # one sanitized summary line (counts and states only)
nix run .#kwin-bridge -- --check --global-menu   # plus menu_status / menu_root_items / menu_items of the active window
nix run .#kwin-bridge -- --version
```

Never run the bridge without `--check` on a terminal you will paste from: its normal output contains window titles and menu labels.

The bridge forces `QT_QPA_PLATFORM=offscreen`, so it never opens a second Qt Wayland connection or initialises EGL. On hybrid AMD/NVIDIA laptops an EGL initialisation can wake the discrete GPU. It still needs a `QGuiApplication`, because KWayland decodes window icons.

Exit codes: `0` when the parent went away, `2` for usage errors or no Wayland connection, `3` when the Wayland connection was lost (KWin restart). KWinBackend restarts the bridge with backoff (1 s, doubling up to 30 s).

## Status

- **Compile:** clean (`-Wall -Wextra`) against the real Qt 6.12 and KWayland 6.8.2 headers, and built by CI on Linux.
- **Smoke test** (CI, `nix/kwin-smoke.sh`): against a headless KWin 6.8.2, `--check` reports window management, desktops and layouts, and sees KWrite open and active. The real bridge's messages are checked against the protocol with `fake-bridge.py --validate`.
- **Not run yet:** a real Plasma session. In particular the D-BusMenu path is untested: CI has no kded AppMenu registrar, so no app exports a menu there. See `handoff/06-kwin-testing-guide.md`.

`fake-bridge.py` speaks the same protocol with made-up data, for testing MacShell's UI without KWin (see its header).
