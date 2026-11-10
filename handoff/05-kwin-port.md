# KWin port: implementation state (branch `kwin-port`)

This brief stands alone. `AGENTS.md` remains the authority. This file records what the `kwin-port` branch implements, the decisions behind it, and what is still unverified. Initial development was done without Plasma, then the integrated shell was tested in the user's Plasma 6 Wayland/KWin session. The shell runs. An earlier live test found the Global Menu hidden, showing mock items instead of the application's own menus. On 2026-11-04 the user reported that the AppMenu export now works, along with six remaining bugs. The fixes for those bugs, not yet run in Plasma, are on `kwin-plasma-fixes` ([`08-plasma-fixes-tests.md`](08-plasma-fixes-tests.md)). Fork housekeeping is on `fork-credits-readme` ([`09-fork-credits-readme.md`](09-fork-credits-readme.md)). See [`06-kwin-testing-guide.md`](06-kwin-testing-guide.md) for the general runbook.

## Validation so far

| Check | Where | Result |
| --- | --- | --- |
| Bridge compiles (`clang++ -fsyntax-only -Wall -Wextra`, moc output included) against the real Qt 6.12.0 and KWayland 6.8.2 headers | macOS | clean |
| Flake evaluation (all systems), builds of `macshell-kwin-bridge`, `macshell` and `macshell-hyprland`; bridge `--version`, and exit 2 without Wayland | CI `build` job | pass |
| ShellCheck, `nix/test-macshell-session.sh` (order of start/coexist/stop and their replace/restore aliases), `fake-bridge.py --selftest` | CI and macOS | pass (2026-11-05 version: the session test passes on macOS `sh` and `dash`; ShellCheck and CI not run yet) |
| `homeManagerModules.macshell` evaluates in a minimal Home Manager configuration (`ExecStart`, `WantedBy=plasma-workspace.target`) | CI | pass |
| qmllint of the compositor backends with Quickshell 0.3.2's types | CI | 0 findings |
| Headless KWin 6.8.2 (`nix/kwin-smoke.sh`, private D-Bus and Wayland socket): the bridge binds window management, sees KWrite open and active, reads desktops and layouts | CI `kwin-smoke` | pass |
| MacShell reaches "Configuration Loaded" under that KWin with the real bridge and with the fake one; the Hyprland IPC client never starts | CI `kwin-smoke` | pass |
| Integrated shell casually runs; latest Global Menu live test: hidden-but-clickable UI, mock/generic items, supported apps still show in-window menus | User's Plasma 6 Wayland session | fail (user-reported), then fixed: on 2026-11-04 the user reports AppMenu export works |
| The real bridge's messages match the protocol (`fake-bridge.py --validate`: hello, session, keyboard, workspaces, windows, menu) | CI `kwin-smoke` | pass |
| QML warnings while MacShell runs 30 s under that KWin (Quickshell's `@file.qml[line:col]` format) | CI `kwin-smoke` | 1, the same with both bridges: `MacDock.qml[1198:25]` cannot open `~/.face` (no avatar on the runner) |
| Independent code review of the branch: 7 bugs and 9 minor points, no blockers | review | bugs fixed in `d1d4cb6` and `37bf077`; the rest are listed below |

Not covered yet: the six fixes in `08`; GTK, Electron, Firefox, VS Code, Xwayland menu exports; broad multi-monitor/hotplug behavior; Klassy; GPU behavior; and Hyprland at runtime.

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
| `flake.nix`, `nix/`                              | New packages `macshell` and `macshell-kwin-bridge`; apps `macshell`, `macshell-session`, `kwin-bridge`; `homeManagerModules.macshell`; dev shell with the bridge, QtMultimedia and python3. The `macshell-hyprland` launcher now uses `-p` and has QtMultimedia. |
| `kwin-bridge/fake-bridge.py`                     | A stand-in bridge with made-up windows, desktops, layouts and menus (`MACSHELL_KWIN_BRIDGE=…`), with `--selftest` and `--validate` against the protocol. |
| `nix/test-macshell-session.sh`, `nix/kwin-smoke.sh`, `.github/workflows/kwin-port.yml` | The session-switcher order test, the headless-KWin smoke test, and CI that runs them with the builds. |

Untouched: `MacLock/`, `MacInstaller/`, `install.sh`, the POCs, and the `macshell-hyprland` package. `WindowBar.qml`, `WindowDecor.qml` and `MinimizeFx.qml` are not instantiated anywhere in this upstream revision, so they need no gate.

## Backend selection and switches

| Variable               | Values                              | Effect                                                                                                                                  |
| ---------------------- | ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `MACSHELL_COMPOSITOR`  | `auto` (default), `hyprland`, `kwin`, `none` | `auto`: Hyprland if `HYPRLAND_INSTANCE_SIGNATURE` is set, KWin if `XDG_CURRENT_DESKTOP` contains `KDE`, otherwise `none` (window features unsupported). |
| `MACSHELL_GLOBAL_MENU` | `1` (default), `0`                  | `0`: the bridge runs without `--global-menu`. It then neither imports menus nor registers `org.kde.kappmenuview`, and the generic menus are used. The bar's own "App menus" widget toggle does the same. |
| `MACSHELL_KDE_MODE`    | unset = `coexist`, `replace`        | `replace` enables MacShell's notification server, but only while plasmashell is not running and nobody else owns the name. In the user manager it is set by `macshell-session start` (the default launch; `replace` is an alias) and, with Home Manager `autostart` and `mode = "replace"` (the default mode), for every login through `systemd.user.sessionVariables`. There it also makes `plasma-plasmashell.service` skip itself (drop-in `ConditionEnvironment=!MACSHELL_KDE_MODE=replace`). `macshell-session coexist`/`stop` and `macshell-fallback.service` (OnFailure of `macshell.service`, after 3 failures in 60 s) unset it and start plasmashell. In `coexist` MacShell serves notifications only when the name has stayed unowned for 15 s (plasmashell without a system tray). |

## Capability matrix (`compositor.can(...)`)

| Feature                             | Hyprland                    | KWin (this branch)                                                                                       |
| ----------------------------------- | --------------------------- | -------------------------------------------------------------------------------------------------------- |
| windows, activate, close, minimize, maximize, fullscreen | Hyprland IPC / `ToplevelManager` | bridge → Plasma Window Management requests                                                               |
| workspaces, switch, move window     | Hyprland workspaces         | KWin virtual desktops (numbered by position, 1-based) via D-Bus; move via PWM enter/leave desktop          |
| focused screen                      | `Hyprland.focusedMonitor`   | screen containing the active window's centre                                                             |
| keyboard layouts                    | `hyprctl devices` (MacBar)  | KWin `org.kde.keyboard /Layouts`, pushed                                                                 |
| global menu                         | no (generic menus)          | active app's D-BusMenu: real titles, items, separators, disabled, check/radio, shortcuts (display), submenus (drill-down), events |
| session: lock / sleep / log out / restart / shut down | MacLock, uwsm or hyprctl exit, systemctl | `org.freedesktop.ScreenSaver.Lock` (KDE's locker), `systemctl suspend`, `org.kde.Shutdown` (saves the session) |
| live window capture (glass, dock previews, tear-off copy) | yes                    | **unsupported** (KWin offers no capture protocol to clients): glass refracts the wallpaper only; previews show app icons. Since 2026-11-10 a minimized window gets one still picture through KWin's `org.kde.KWin.ScreenShot2` D-Bus interface (untested; see [`15`](15-plasma-test-report.md), B6) |
| screen capture (grim, wf-recorder, auto-contrast)          | yes                    | **delegated / off**: Spectacle (`-r`, `-f`, `-a`, `--record region`); auto-contrast falls back to the Light/Dark setting |
| colour picker (hyprpicker)          | yes                         | **unsupported** (menu item hidden)                                                                        |
| Night Shift (hyprsunset)            | yes                         | **delegated**: opens KDE Night Light settings                                                             |
| display modes, input settings       | `hyprctl eval`              | **delegated**: KScreen / keyboard / mouse / touchpad settings modules; saved Hyprland modes are never applied |
| window layout controls (float, pin, split, move/resize) | yes              | **unsupported** (hidden): KWin windows float; KWin's own window menu has the rest                         |
| menu shortcuts in the *generic* menus | `hyprctl sendshortcut` / wtype | `ydotool` only, if installed and running (KWin has no virtual-keyboard protocol for wtype)                 |
| self-drawn titlebars for other apps | (files unused)              | never: KWin and Klassy decorate                                                                          |
| Game Mode                           | script tweaks Hyprland, power profile, mpvpaper | MacShell-internal only (glass and captures quiet); no host settings change                               |
| blur behind panels                  | layer rules (`macbarbg`, …) | bar strip via `ext-background-effect` (`BackgroundEffect`), drawn inside the bar window (no `macbarbg` layer on KWin); the Dock and popovers get KWin blur only with Settings → Appearance → "Use KWin's blur" (`GlassBlur.qml` / `BlurCollector.qml`, untested; see [`11-kwin-blur-tests.md`](11-kwin-blur-tests.md)). Every MacShell layer surface uses the namespace `dock`, which KWin turns into the Dock window type, so force-blur effects leave it alone unless their "Blur docks" option is on |
| wallpaper                           | Noctalia / awww / swww / hyprpaper | read from `plasma-org.kde.plasma.desktop-appletsrc` (wallpaper packages resolved to their largest image); while plasmashell runs, Plasma's wallpaper is what the glass refracts and MacShell's last pick is not re-applied at start; set with `plasma-apply-wallpaperimage` when `org.kde.plasmashell` is on the bus (not `pgrep`: NixOS runs `.plasmashell-wrapped`). Only the first containment's wallpaper is read |
| screen brightness                   | `brightnessctl` / `ddcutil` | PowerDevil's `org.kde.ScreenBrightness` D-Bus API (every display it controls; KDE's OSD suppressed for MacShell's changes) |

## KDE service ownership

| Service                                                     | Owner (coexist)                  | Owner (replace: plasmashell stopped)                    | MacShell behaviour                                                                                               |
| ----------------------------------------------------------- | -------------------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Compositor, decorations (Klassy), screen locker             | KWin                             | KWin                                                    | never replaced; lock goes to KDE's locker                                                                         |
| Notifications (`org.freedesktop.Notifications`)             | plasmashell's system tray; MacShell when no tray has claimed it for 15 s | MacShell (`MACSHELL_KDE_MODE=replace`)                  | MacShell's server never starts while another process owns the name. Quickshell's server is process-wide, disallows replacement and re-claims the name, so `coexist`/`stop` stop MacShell first, and a Plasma tray added later in the same login gets no notifications until MacShell is stopped and plasmashell restarted. |
| Tray watcher (`org.kde.StatusNotifierWatcher`)              | kded6                            | kded6                                                   | Quickshell registers as a host only. Its fallback watcher would claim the name only if kded's went away.          |
| Global menu view (`org.kde.kappmenuview`)                   | Plasma applet, if in a panel     | bridge (`--global-menu`)                                | queued registration like the applet; keeps kded's registrar alive                                                 |
| OSD (volume/brightness popups), clipboard history (Klipper), desktop (folder view, widgets) | plasmashell     | **gone** for that login                                 | MacShell has its own volume/brightness OSD only for keys bound to its IPC. Klipper history and Plasma's desktop are lost in replace mode (documented trade-off). |
| Wallpaper; KSplash's last stage (`desktop`)                 | plasmashell                      | MacShell (`Wallpaper.qml`, branch `kwin-replace-wallpaper-splash`, untested) | Active only while the bridge reports no plasmashell (`compositor.desktopUnserved`). Draws `MacDock.wallpaperFor()` on a `desktop`-namespace Background layer; the picker skips wallpaper daemons in this mode. Sends `setStage desktop` once the picture loads (3 s fallback) with `busctl --auto-start=no`. |
| Polkit agent, PowerDevil, portals, kded, KIO, PipeWire, NetworkManager, Bluetooth | their own units | unchanged                                     | untouched                                                                                                        |

## Known gaps and risks (honest list)

- **2026-11-04 update:** the user reports the AppMenu export problem below is fixed in their session. Six follow-up bugs (bar background, force blur, brightness, notifications without a Plasma tray, wallpaper sync, menu icons) have unverified fixes on branch `kwin-plasma-fixes`; see [`08-plasma-fixes-tests.md`](08-plasma-fixes-tests.md).

- **Global Menu live failure (superseded 2026-11-04: the user reports export works now; kept for history).** Earlier user report: bar menu is hidden but clickable, it shows mock/generic items, and apps that export AppMenu still render in-window menus. Determine whether the appmenu view registration, app address discovery, D-BusMenu import, or visibility state is at fault before accepting the feature. Earlier positive display/action reports are superseded.
- Global menu: export works in the user's session (2026-11-04). Keyboard navigation is unsupported. Item icons are shown (theme names, and Qt's `icon-data` PNGs as data URLs) but not yet verified live. Production label normalization strips mnemonic markers (`_File` → `File`, `__` → `_`) and preserves a trailing underscore, but it has not been verified against real app-menu labels. Keyboard mnemonic activation/underlining is not implemented. The indeterminate check state renders as unchecked. Submenus drill down inside the popover (the same pattern as the tray menu) instead of cascading. Apps started before a menu view existed keep their in-window menu bars until restarted. GTK, Electron, Firefox and VS Code exports are untested. Xwayland apps should work, because KWin publishes their `_KDE_NET_WM_APPMENU_*` address through the same protocol, but this is untested.
- Coexist mode overlaps if Plasma has a panel on the same edge: move/auto-hide Plasma's panel, turn off MacShell's Dock/bar on that screen, or use replace mode. MacShell's desktop icons duplicate Plasma's Folder View desktop; turn one of them off.
- MacShell's notification bell is empty in coexist mode while plasmashell's tray serves notifications.
- Hyprland behaviour is meant to be unchanged (same dispatch strings, same pollers, gated by `isHyprland`; the review found and fixed two regressions). It was not re-tested at runtime; see guide §16.
- The Settings, About and Clock windows draw their own frame (frameless, client-side). KWin does not add a Klassy titlebar to them.
- Generic-menu shortcut items need `ydotool` 1.x and its `ydotoold` socket on KWin, which has no virtual-keyboard protocol for `wtype`. Without them the items are greyed out.
- Other wlroots compositors (Sway, niri, river) now get the `none` backend: no window list, MacLock or notification server there, although `ToplevelManager` used to work. Upstream targeted Hyprland only; a thin generic backend on `ToplevelManager` would restore it.
- KWin per-output virtual desktops (off by default) are not reflected: every screen shows the global current desktop.
- In-app "update MacShell" (upstream's self-update) cannot write into the Nix store. On `fork-credits-readme`, Settings → Software Update checks this fork (`OngYean/MacShell-KWin`) and only notifies; updating goes through Nix or git.
