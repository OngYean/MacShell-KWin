# KWin port: testing guide (for the agent guiding the user)

You are guiding the user through the first real test of the `kwin-port` branch in their KDE Plasma 6 Wayland session. Read `AGENTS.md` (authoritative) and [`05-kwin-port.md`](05-kwin-port.md) (what was built) first. **Nothing on this branch has been compiled or run yet**: it was written on a machine without Qt, Nix or Plasma, and checked only with syntax parsers. Expect build errors in §2 and fix them as small, separate commits.

Work through the sections in order. Each step lists the command, what the user should see, and what to record. Fill in the results table (§17) as you go.

## 0. Ground rules

- **Approval gates.** The steps marked **[ask]** stop plasmashell, suspend, end the session, change a setting, or touch the user's Nix configuration. Get an explicit yes for each one, every time. Everything else runs as the user, in the foreground, and reverses itself with `Ctrl+C`.
- **Never** run `install.sh`, use `sudo`, enable, disable or mask units, or edit `kwinrc` or Plasma configuration files yourself. Klassy installation and selection is the user's decision (§13).
- **Sensitive output.** The bridge's normal output and the QML console can contain window titles and menu labels. Share only `--check` output (counts and states), exit codes and QML warning lines. Never paste raw bridge output, `getWindowInfo`, or `supportInformation` (it lists windows).
- **Rollback at any point:** `Ctrl+C` the foreground MacShell, or run `macshell kill`. If plasmashell was stopped, run `systemctl --user start plasma-plasmashell.service`. As a last resort, log out and back in: nothing on this branch persists across logins unless the Home Manager module was switched in (§14).
- **Don't run `nvidia-smi`** during GPU checks: it wakes the NVIDIA GPU itself (§12).

## 1. Preflight

```sh
cd ~/path/to/MacShell-KWin && git switch kwin-port && git status --short && git log --oneline -8
echo "$XDG_SESSION_TYPE $XDG_CURRENT_DESKTOP"            # expect: wayland KDE
plasmashell --version; kwin_wayland --version             # recorded so far: 6.8.2
kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library   # org.kde.breeze today; org.kde.klassy once Klassy is selected
systemctl --user is-active plasma-plasmashell.service     # active
kscreen-doctor -o | grep -E '^Output|Scale|Geometry'      # outputs, scale, geometry (recorded so far: eDP-1 1920x1080, DP-2)
for d in /sys/bus/pci/devices/*; do [ "$(cat "$d/vendor")" = 0x10de ] && echo "$d $(cat "$d/power/runtime_status")"; done   # NVIDIA baseline
```

Record each value. Note where Plasma's panels are: the bar and Dock reserve the top and bottom edges of every screen, so a Plasma panel on the same edge will overlap (see §3).

## 2. Build and static checks

```sh
nix flake check --no-build                     # evaluation of all outputs (an "unknown output homeManagerModules" warning is fine)
nix build .#macshell-kwin-bridge -L            # first compile of the bridge
nix build .#macshell -L                        # the shell package (config + wrappers)
nix develop --command shellcheck nix/macshell.sh nix/macshell-session.sh
nix develop --command qmllint MacShell/backends/compositor/*.qml   # report syntax errors; "module not found" for Quickshell imports is expected
```

- Bridge compile errors are most likely small Qt or KWayland signature mismatches. Fix them in `kwin-bridge/main.cpp` and re-run, keeping the behaviour described in `kwin-bridge/README.md`. Commit the fix on its own (`fix(kwin-bridge): …` once it builds and §3 passes, `wip(…)` before then; see AGENTS.md §12).
- If `nix build .#macshell` fails on `qt6.qtmultimedia` / `qtQmlPrefix` / `qtPluginPrefix`, check those attribute names at the locked nixpkgs revision.

## 3. Bridge diagnostics (counts only)

```sh
nix run .#kwin-bridge -- --version
nix run .#kwin-bridge -- --check
```

Expected: `status=ok window_management=available advertised_version=21 windows=N active_window_present=true … desktops=N current_desktop_known=true keyboard_layouts=N plasmashell=true notifications_owner=other`. KWin advertises v21; KWayland binds at most v18.

Global menu check. Ask the user to click into KWrite within 5 seconds:

```sh
sleep 5; nix run .#kwin-bridge -- --check --global-menu
```

Expected second line: `menu_status=ok menu_root_items=8 menu_items=…`. The POC recorded 8 root and 132 total items for native-Wayland KWrite. If the status is `loading`, re-run it; the fetch is asynchronous with a 1.5 s window. `none` means the app exported no menu (see §7).

## 4. Run MacShell next to plasmashell ("coexist")

Run in the foreground so `Ctrl+C` stops it:

```sh
nix run .#macshell
# or, while editing QML (live reload, straight from the work tree):
nix develop --command qs -p ./MacShell
```

Ask the user to check, and record the result of each:

| Check | Expected |
| --- | --- |
| Menu bar | On every screen, at the top. A maximized window starts below it (exclusive zone). |
| Dock | Bottom of the main display. No overlap with a Plasma panel. If one overlaps, ask the user to set it to auto-hide or turn MacShell's Dock off for that screen; don't move it yourself. |
| App decorations | Unchanged (Breeze or Klassy title bars, rounded corners, shadows). MacShell draws no titlebar over other apps. |
| MacShell's own windows | Settings (Apple menu → System Settings…), About and Clock show MacShell's own frame and traffic lights, with no KDE titlebar on top. |
| Liquid Glass | Refracts the Plasma wallpaper (not black). Windows behind the glass are *not* shown: that's expected, KWin has no capture for clients. |
| Bar strip blur | With Settings → Menu Bar → Bar background > 0, KWin blurs what is behind the strip. Plasma's blur effect must be enabled. |
| Quickshell log | `macshell log` (or the foreground terminal): no `ReferenceError` / `TypeError` / `is not a type` / `module … not installed`. A single `HYPRLAND_INSTANCE_SIGNATURE is unset` line would point to an ungated `Hyprland` use: record the file/line it names. |

No polling of absent tools (battery). While MacShell runs, idle for 10 s:

```sh
for i in $(seq 40); do pgrep -x hyprctl; pgrep -x grim; pgrep -x hyprsunset; sleep 0.25; done   # expect no output
pgrep -af macshell-kwin-bridge                                                                   # exactly one bridge
top -b -n 3 -d 2 -p "$(pgrep -d, -f 'qs -p')" | tail -n 3                                         # idle CPU near 0 %
```

## 5. Windows and the Dock

Open KWrite, Dolphin and Konsole, plus one Xwayland window (`QT_QPA_PLATFORM=xcb kwrite &`).

| Action | Expected |
| --- | --- |
| Running apps | Indicators under their Dock icons; unpinned apps appear in the Dock; the Xwayland window is listed. |
| Click an icon | The app comes to the front, switching virtual desktop if needed. Clicking again cycles that app's windows. |
| Right-click an icon | Window list (✓ on the active one), New Window, Quit. Quit closes all of that app's windows. |
| Menu bar app menu → Hide KWrite | Its windows minimise. **Show All** brings them back. |
| Window menu | **Minimize**, **Zoom** (maximise toggle), **Move to Next / Previous Workspace** (with 2+ desktops). The list of open windows switches between them. |
| View → Enter Full Screen | Toggles fullscreen. |
| Spotlight (search icon), type part of a window title | "Open Window" results activate that window. |
| Window switcher (needs a shortcut, §15) | Cycles apps; committing activates the window. |
| Smart hide (if enabled in Dock settings) | The Dock hides while a maximised or fullscreen window covers its screen, and comes back otherwise. |
| Window previews | Show app icons (no live capture on KWin); Dock Preferences → "Live window capture" has no effect here. |

## 6. Workspaces

Use the user's existing virtual desktops. If there is only one, ask **[ask]** before adding one in System Settings → Virtual Desktops, and remove it afterwards.

- The bar's workspace numbers match KWin's desktops (1..N in desktop order); the current one is highlighted; numbers of desktops with windows are brighter.
- Clicking a number switches desktop; scrolling over the numbers moves to the next or previous one (wrapping).
- Switch desktops with KDE's own shortcuts: the bar follows.

## 7. Global menu

Comparison baseline: if the user has Plasma's Global Menu widget in a panel, it must keep working and show the same top-level titles.

For each app below, focus it and record: titles shown, submenu navigation, disabled items, check marks, shortcuts, one benign action **[ask]**, and switching away and back.

| # | App / backend | How to start | Notes |
| --- | --- | --- | --- |
| 1 | KWrite, native Wayland | `kwrite` | baseline; the POC saw 8 root items |
| 2 | KWrite, Xwayland | `QT_QPA_PLATFORM=xcb kwrite` | address comes from X properties via KWin |
| 3 | Dolphin / Konsole (Qt) | from the launcher | Konsole has a menu bar |
| 4 | GTK 3 app | e.g. `gnome-text-editor` / `gedit` | GTK needs appmenu-gtk-module or Plasma's GMenu proxy (`plasma-gmenudbusmenuproxy.service`, X11 only); record what happens |
| 5 | Electron | VS Code (`code`), Wayland and `--ozone-platform=x11` | Electron exports D-Bus menus mainly under X11; record |
| 6 | Firefox | Wayland and `MOZ_ENABLE_WAYLAND=0 firefox` | Firefox normally has no global menu; generic menus expected |
| 7 | An app started *before* MacShell with no Plasma Global Menu widget present | — | expected: no export until restarted (Qt checks the registrar once per process) |

Expected behaviour for apps that export a menu:

- The bar shows Apple menu, the **bold app name** (MacShell's About/Hide/Quit menu), then the app's own titles (File, Edit, …), not the generic ones.
- A title opens a popover with real items: separators, greyed disabled items, ✓ on checked toggles and radios, shortcuts shown as `Ctrl+…`.
- Items with a submenu show `›`. Clicking one opens that submenu inside the popover, and the `‹ Name` row goes back. Lazily filled submenus (Recent Files, Encoding) fill in after a moment.
- A benign leaf action **[ask]**, e.g. KWrite View → Show Line Numbers or Help → About KWrite, performs that action; the popover closes.
- Switching apps swaps the titles. An app without an exported menu, and the desktop itself, show the generic File/Edit/View/Window/Help menus.
- `MACSHELL_GLOBAL_MENU=0 nix run .#macshell` always shows the generic menus.

Known limits, so don't report these as bugs: no keyboard navigation, mnemonics or icons; the indeterminate state shows as unchecked; generic-menu shortcut items need `ydotool` (KWin has no virtual-keyboard protocol for `wtype`).

## 8. Session actions

| Action | Expected |
| --- | --- |
| Apple menu → Lock Screen | KDE's own lock screen (not MacLock). Unlock with the password; MacShell is still there. |
| Apple menu → Sleep **[ask]** | Suspends. On resume, KDE locks (per its settings), then the bar, Dock and global menu work. The bridge PID may stay the same. |
| Log Out… / Restart… / Shut Down… **[ask]** (each ends the session; do them last or skip) | The first click arms the item ("Click again to confirm"), the second calls `org.kde.Shutdown`. Plasma ends the session cleanly, with session restore as usual. |

## 9. KDE services stay KDE's

```sh
busctl --user status org.freedesktop.Notifications | grep -E '^(PID|Comm)='   # coexist: plasmashell
busctl --user status org.kde.StatusNotifierWatcher | grep -E '^(PID|Comm)='   # kded6
busctl --user status org.kde.kappmenuview | grep -E '^(PID|Comm)='            # plasmashell (applet) or macshell-kwin-bridge
notify-send "MacShell test" "coexist"                                          # shown by Plasma, not by MacShell
```

- **Polkit:** open a KDE settings page with an **Unlock** button (e.g. Date & Time) and cancel the prompt. The KDE prompt appears.
- **Tray:** MacShell's tray shows the same apps as Plasma's (e.g. KDE Connect, Discord, Steam). Right-click menus work.
- **Screenshots:** MacShell File → Screenshot Screen / Selection… / Window use Spectacle (region selection is Spectacle's overlay). The file goes where MacShell's Menu Bar settings say. The KDE `Print` shortcut still opens Spectacle.
- **Screen recording:** File → Start Screen Recording opens Spectacle's region recorder.
- **Screen sharing:** in a browser test page that shares the screen, the KDE portal's picker appears and sharing works. MacShell's purple privacy dot shows "Screen Sharing".
- **Clipboard:** copy and paste between apps works; Klipper history is still in Plasma's tray.
- **Network, Bluetooth, audio, brightness:** MacShell's Control Center tiles work (nmcli, bluetoothctl, PipeWire, brightnessctl). KDE's volume and brightness keys still show Plasma's OSD in coexist mode.

## 10. Replace mode and back **[ask]**

This stops plasmashell for this login only: panels, desktop and wallpaper, notifications, OSD and clipboard history vanish until restore.

```sh
nix shell .#macshell --command macshell-session status
nix shell .#macshell --command macshell-session replace
notify-send "MacShell test" "replace"                                          # now shown by MacShell (top-right banner + bell)
busctl --user status org.freedesktop.Notifications | grep -E '^(PID|Comm)='   # Comm=qs (or .quickshell-wrapped)
busctl --user status org.kde.kappmenuview | grep -E '^(PID|Comm)='            # macshell-kwin-bridge: the global menu still works (re-check KWrite)
nix shell .#macshell --command macshell-session restore                       # plasmashell back; notifications owned by plasmashell again
```

`macshell-session` restarts MacShell detached when no `macshell.service` exists. Stop that copy with `nix shell .#macshell --command macshell kill`. If anything breaks, run `systemctl --user start plasma-plasmashell.service` and log out and in.

Known trade-offs in replace mode: no wallpaper is drawn unless a wallpaper daemon (awww/swww) is installed, and there is no Klipper history and no Plasma OSD.

## 11. Displays, scaling, hotplug

- **Two screens:** a bar on each, the Dock on the main display (Dock Settings → Displays → Main display; that list now comes from the screens KWin reports). Displays → "Arrangement & Resolution" opens KDE's display settings: MacShell no longer applies modes saved under Hyprland.
- **Hotplug:** unplug and replug the external screen. Its bar comes back and nothing crashes (`macshell log`).
- **Scaling** **[ask]** (a KDE display setting, revert it afterwards): try 125 % and 150 %. Text is sharp, the bar height is right, and the Dock and popovers sit at the right edges.

## 12. Hybrid GPU (no NVIDIA wake-ups)

With MacShell idle for 2 minutes and no NVIDIA app running:

```sh
for d in /sys/bus/pci/devices/*; do [ "$(cat "$d/vendor")" = 0x10de ] && echo "$d $(cat "$d/power/runtime_status")"; done   # expect: suspended (same as §1)
```

Repeat with the global menu in use and right after starting MacShell; record any `active`. The bridge runs with `QT_QPA_PLATFORM=offscreen` and opens no EGL context. Quickshell itself renders on KWin's GPU. Don't change the DRM device or PRIME settings.

## 13. Klassy **[ask: the user installs and selects it]**

Once Klassy is the KWin decoration (`kreadconfig6 … --key library` prints `org.kde.klassy`), repeat §4's decoration check and §5 with MacShell running. Klassy's titlebars, buttons and shadows should be untouched, and Klassy's own application-menu button (if enabled) still opens the app's menu.

## 14. Nix reproducibility and Home Manager **[ask: this edits the user's Nix config]**

The user's NixOS or Home Manager repository is not in this workspace. In their repository:

```nix
inputs.macshell.url = "github:OngYean/MacShell-KWin/kwin-port";   # or path:/…/MacShell-KWin for a local test
# in the Home Manager configuration:
imports = [ inputs.macshell.homeManagerModules.macshell ];
programs.macshell.enable = true;        # package + macshell.service (not started automatically)
# programs.macshell.autostart = true;   # only after everything above passed
```

`home-manager build` (or `nixos-rebuild build`) first, then switch only with approval. Then:

```sh
systemctl --user start macshell.service && systemctl --user status macshell.service --no-pager
macshell-session status
macshell ipc call spotlight toggle      # IPC reaches the service instance
```

To roll back, set `enable = false` (or remove the import) and switch again; plasmashell was never disabled.

## 15. Shortcuts (optional) **[ask]**

KDE System Settings → Keyboard → Shortcuts → Add New → Command. Use the packaged wrapper so the command keeps working across store paths:

- `macshell ipc call spotlight toggle` (e.g. Meta+Space)
- `macshell ipc call switcher next` (KWin's own Alt+Tab stays the default; don't replace it)
- `macshell ipc call wallpapers toggle`

## 16. Crash recovery and regression

```sh
pkill -f macshell-kwin-bridge; sleep 3; pgrep -af macshell-kwin-bridge   # restarted by KWinBackend within ~2 s; Dock and menu recover
```

If the user also has a Hyprland session, spot-check `nix run .#macshell` there: menus, Dock, previews, glass and workspaces should behave as before the port.

## 17. Results

Copy this table into the next handoff update and fill it in. Use `pass` / `fail` / `partial` / `skipped`, with one line of evidence each.

| AGENTS.md acceptance criterion | Guide § | Result | Evidence |
| --- | --- | --- | --- |
| Plasma Wayland session starts normally | 1, 14 | | |
| KWin remains the compositor | 1, 4 | | |
| Klassy keeps providing decorations | 13 | | |
| MacShell menu bar and Dock render correctly | 4 | | |
| Global menus show real app menus (Qt, GTK, Electron, Firefox, VS Code; Wayland and Xwayland) | 3, 7 | | |
| Application activation and window management work | 5 | | |
| Workspaces and multiple displays work | 6, 11 | | |
| Polkit prompts work | 9 | | |
| Notifications and system tray work | 9, 10 | | |
| Screen sharing and screenshots work | 9 | | |
| Native screen locking and session management work | 8 | | |
| Sleep, resume and display hotplug don't break the shell | 8, 11 | | |
| No unnecessary NVIDIA wake-ups | 12 | | |
| Reproducible through Nix | 2, 14 | | |
| Original Plasma desktop stays recoverable | 10, 14 | | |

After testing: update `handoff/00-project-state.md`, `05-kwin-port.md` and this table. Commit per AGENTS.md §12. Change `wip` to `feat`/`fix` only for behaviour that passed here.

## Triage

| Symptom | Look at |
| --- | --- |
| Shell doesn't load: `module "QtMultimedia" is not installed` | `QML_IMPORT_PATH` in the `macshell` wrapper / dev shell (`flake.nix`) |
| Empty Dock, no window list, menus generic everywhere | `macshell-kwin-bridge --check`; `pgrep -af macshell-kwin-bridge`; a `status=…` line in `macshell log` |
| Global menu `none` for a Qt app | Was the app started before a menu view existed? `busctl --user status com.canonical.AppMenu.Registrar` (kded) and `org.kde.kappmenuview` |
| Clicking a menu item does nothing | The bridge drops events for stale windows, disabled items or submenus by design; re-open the menu |
| Notifications missing in coexist mode | They are Plasma's: is plasmashell running? MacShell's bell stays empty by design |
| Notifications missing after `restore` | MacShell held the name: `macshell-session restore` stops it first. Run `systemctl --user restart plasma-plasmashell.service` |
| Overlapping panels | A Plasma panel shares an edge with MacShell's bar or Dock (§4) |
