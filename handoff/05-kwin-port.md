# KWin port: implementation state (branch `kwin-port`)

This brief stands alone. `AGENTS.md` remains the authority. This file records what the `kwin-port` branch implements, the decisions behind it, and what is still unverified. Every item below was written and **statically checked only**: the work was done on a macOS machine with no Plasma session, no Nix and no Qt. To test it, follow [`06-kwin-testing-guide.md`](06-kwin-testing-guide.md).

## What changed

| Path                                             | What                                                                                                                                       |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `kwin-bridge/`                                   | `macshell-kwin-bridge`: event-driven C++ helper (Qt 6, KWayland), promoted from `poc/kwin-backend-probe`. Protocol and decision record are in its README. |
| `MacShell/backends/compositor/Compositor.qml`    | The facade: picks a backend and is the only compositor API the UI uses (`hub.compositor`).                                                 |
| `MacShell/backends/compositor/HyprlandBackend.qml` | The original Hyprland calls, moved verbatim (dispatch strings, MacLock, uwsm / hyprctl exit).                                            |
| `MacShell/backends/compositor/KWinBackend.qml`   | Drives the bridge and keeps stable Toplevel-like window objects. Produces `hyprctl`-shaped `clients` / `monitors` / `activeWindow` so the existing glass and smart-hide code is reused. |
| `MacShell/shell.qml`                             | Creates the facade. Hyprland pollers and capture admission now run only on Hyprland. On KWin, geometry comes from the backend and the wallpaper lookup reads Plasma's `appletsrc`. |
| `MacShell/MacBar.qml`                            | Active app, menus, session actions, workspaces, switcher, keyboard layouts and Game Mode go through the facade. Adds the **global menu renderer**. Spectacle handles screenshots/recording on KWin; capture-dependent features are gated; the bar strip blurs via `BackgroundEffect`. |
| `MacShell/MacDock.qml`                           | Window list and actions through the facade. Smart-hide uses backend snapshots. Previews and tear-off are capture-gated. Displays/Keyboard/Mouse/Trackpad panes open KDE settings on KWin. |
| `MacShell/AboutApp.qml`, `MacShell/ClockApp.qml` | Hyprland window rules only on Hyprland; focused screen from the facade.                                                                    |
| `flake.nix`, `nix/`                              | New packages `macshell` and `macshell-kwin-bridge`; apps `macshell`, `macshell-session`, `kwin-bridge`; `homeManagerModules.macshell`; dev shell with the bridge and QtMultimedia. |

Untouched: `MacLock/`, `MacInstaller/`, `install.sh`, the POCs, and the `macshell-hyprland` package. `WindowBar.qml`, `WindowDecor.qml` and `MinimizeFx.qml` are not instantiated anywhere in this upstream revision, so they need no gate.

## Backend selection and switches

| Variable               | Values                              | Effect                                                                                                                                  |
| ---------------------- | ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `MACSHELL_COMPOSITOR`  | `auto` (default), `hyprland`, `kwin`, `none` | `auto`: Hyprland if `HYPRLAND_INSTANCE_SIGNATURE` is set, KWin if `XDG_CURRENT_DESKTOP` contains `KDE`, otherwise `none` (window features unsupported). |
| `MACSHELL_GLOBAL_MENU` | `1` (default), `0`                  | `0`: the bridge runs without `--global-menu`. It then neither imports menus nor registers `org.kde.kappmenuview`, and the generic menus are used. The bar's own "App menus" widget toggle does the same. |
| `MACSHELL_KDE_MODE`    | `coexist` (default), `replace`      | `replace` enables MacShell's notification server, but only while plasmashell is not running and nobody else owns the name. Set by `macshell-session replace`; never automatic. |

## Capability matrix (`compositor.can(...)`)

| Feature                             | Hyprland                    | KWin (this branch)                                                                                       |
| ----------------------------------- | --------------------------- | -------------------------------------------------------------------------------------------------------- |
| windows, activate, close, minimize, maximize, fullscreen | Hyprland IPC / `ToplevelManager` | bridge → Plasma Window Management requests                                                               |
| workspaces, switch, move window     | Hyprland workspaces         | KWin virtual desktops (numbered by position, 1-based) via D-Bus; move via PWM enter/leave desktop          |
| focused screen                      | `Hyprland.focusedMonitor`   | screen containing the active window's centre                                                             |
| keyboard layouts                    | `hyprctl devices` (MacBar)  | KWin `org.kde.keyboard /Layouts`, pushed                                                                 |
| global menu                         | no (generic menus)          | active app's D-BusMenu: real titles, items, separators, disabled, check/radio, shortcuts (display), submenus (drill-down), events |
| session: lock / sleep / log out / restart / shut down | MacLock, uwsm or hyprctl exit, systemctl | `org.freedesktop.ScreenSaver.Lock` (KDE's locker), `systemctl suspend`, `org.kde.Shutdown` (saves the session) |
| live window capture (glass, dock previews, tear-off copy) | yes                    | **unsupported** (KWin offers no capture protocol to clients): glass refracts the wallpaper only; previews show app icons |
| screen capture (grim, wf-recorder, auto-contrast)          | yes                    | **delegated / off**: Spectacle (`-r`, `-f`, `-a`, `--record region`); auto-contrast falls back to the Light/Dark setting |
| colour picker (hyprpicker)          | yes                         | **unsupported** (menu item hidden)                                                                        |
| Night Shift (hyprsunset)            | yes                         | **delegated**: opens KDE Night Light settings                                                             |
| display modes, input settings       | `hyprctl eval`              | **delegated**: KScreen / keyboard / mouse / touchpad settings modules; saved Hyprland modes are never applied |
| window layout controls (float, pin, split, move/resize) | yes              | **unsupported** (hidden): KWin windows float; KWin's own window menu has the rest                         |
| menu shortcuts in the *generic* menus | `hyprctl sendshortcut` / wtype | `ydotool` only, if installed and running (KWin has no virtual-keyboard protocol for wtype)                 |
| self-drawn titlebars for other apps | (files unused)              | never: KWin and Klassy decorate                                                                          |
| Game Mode                           | script tweaks Hyprland, power profile, mpvpaper | MacShell-internal only (glass and captures quiet); no host settings change                               |
| blur behind panels                  | layer rules (`macbarbg`, …) | bar strip via `ext-background-effect` (`BackgroundEffect`); the Dock and popovers have no KWin blur yet    |
| wallpaper                           | Noctalia / awww / swww / hyprpaper | read from `plasma-org.kde.plasma.desktop-appletsrc`; set with `plasma-apply-wallpaperimage` while plasmashell runs |

## KDE service ownership

| Service                                                     | Owner (coexist)                  | Owner (replace: plasmashell stopped)                    | MacShell behaviour                                                                                               |
| ----------------------------------------------------------- | -------------------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Compositor, decorations (Klassy), screen locker             | KWin                             | KWin                                                    | never replaced; lock goes to KDE's locker                                                                         |
| Notifications (`org.freedesktop.Notifications`)             | plasmashell                      | MacShell (`MACSHELL_KDE_MODE=replace`)                  | MacShell's server starts only in replace mode, only after the bridge reports nobody else owns the name. Quickshell's server is process-wide and re-claims the name, so `restore` stops MacShell first. |
| Tray watcher (`org.kde.StatusNotifierWatcher`)              | kded6                            | kded6                                                   | Quickshell registers as a host only. Its fallback watcher would claim the name only if kded's went away.          |
| Global menu view (`org.kde.kappmenuview`)                   | Plasma applet, if in a panel     | bridge (`--global-menu`)                                | queued registration like the applet; keeps kded's registrar alive                                                 |
| OSD (volume/brightness popups), clipboard history (Klipper), desktop/wallpaper | plasmashell     | **gone** for that login                                 | MacShell has its own volume/brightness OSD only for keys bound to its IPC. Klipper history and Plasma's desktop are lost in replace mode (documented trade-off). |
| Polkit agent, PowerDevil, portals, kded, KIO, PipeWire, NetworkManager, Bluetooth | their own units | unchanged                                     | untouched                                                                                                        |

## Known gaps and risks (honest list)

- **Nothing here has run.** The bridge has not been compiled; tree-sitter parse checks are syntax only. The first test step is `nix build .#macshell-kwin-bridge`.
- Global menu: no keyboard navigation, mnemonics or icons. The indeterminate check state renders as unchecked. Submenus drill down inside the popover (the same pattern as the tray menu) instead of cascading. Apps started before a menu view existed keep their in-window menu bars until restarted. GTK, Electron, Firefox and VS Code exports are untested. Xwayland apps should work, because KWin publishes their `_KDE_NET_WM_APPMENU_*` address through the same protocol, but this is untested.
- Coexist mode overlaps if Plasma has a panel on the same edge: move/auto-hide Plasma's panel, turn off MacShell's Dock/bar on that screen, or use replace mode. MacShell's desktop icons duplicate Plasma's Folder View desktop; turn one of them off.
- MacShell's notification bell is empty in coexist mode (plasmashell shows the notifications).
- Hyprland behaviour is meant to be unchanged (same dispatch strings, same pollers, gated by `isHyprland`). It was not re-tested either; see guide §12.
- The Settings, About and Clock windows draw their own frame (frameless, client-side). KWin does not add a Klassy titlebar to them.
- The existing `macshell-hyprland` package still passes a store path to `qs -c`; that only works by accident of Quickshell's path joining. It also lacks QtMultimedia on the QML path. The new `macshell` package uses `-p` and adds QtMultimedia.
- In-app "update MacShell" (upstream's self-update) cannot write into the Nix store.
