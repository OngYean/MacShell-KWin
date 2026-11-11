# Plasma 6.8 test report (2026-11-10): bugs and feature requests

`AGENTS.md` remains the authority. This file is the shared list of what the user found when running branch `pending-test` on a real KDE Plasma 6.8 Wayland session **with `plasmashell` disabled** (Home Manager `autostart = true`, `mode = "replace"`), and of the features they asked for. Work on it happens on `pending-test`, one commit per item.

Each item has an ID. Use it in commit bodies and when reporting test results.

**Continued in [`16-blur-panels-report.md`](16-blur-panels-report.md)** (2026-11-11): the user's next test confirmed that KWin's blur shows (B1) and that the Dock size change is better but still slow (B2, continued as B7), and found that B6 added a setting that duplicates an existing one (B11: `minimizedSnapshots` is removed, "Show window previews" covers it).

## Reported bugs

| ID | Report (user's words, shortened) | Status |
| --- | --- | --- |
| B1 | With "Use KWin's blur" on, the shell's surfaces turn transparent but nothing is blurred behind them. MacShell's Settings window does get force blur on its side panel. | fix written (`b58b299`) |
| B2 | MacShell freezes for 5–10 s when the Dock size is changed in Settings. | fix written (`c69c2ed`) |
| B3 | Log Out from the top-left menu does nothing. Plasma has its own session implementation, and some `loginctl` commands have quirks there. | fix written (`8d2ab49`) |
| B4 | `plasma-workspace.target: Found ordering cycle: macshell.service/start after graphical-session.target/start after plasma-workspace.target/start after macshell.service`. The splash screen stays for a long time, then a Plasma session without a shell starts. | fix written (`eccded9`) |
| B5 | After unlocking, MacShell takes a while to bring its elements back. Until then the Dock has no icons, and neither has the top bar. | needs diagnosis |
| B6 | In the Dock, a minimized window should show a small snapshot of itself as its icon by default, as on macOS. | written (`3a9ac7b` bridge, `72bcae0` Dock); bridge not compiled yet |

## Requested features

| ID | Request | Status |
| --- | --- | --- |
| F1 | The global menu's popover grows wider to fit its text, so labels are not cut off with "…". | written (`898b6b7`) |
| F2 | An option to open a submenu to the right of its parent menu, instead of replacing the menu with a "back" entry. | written (`df80830`) |
| F3 | Start applications as systemd units where possible, not as children of the MacShell process. | written (`cf78ab7`) |
| F4 | The Dock icon's right-click menu and Spotlight (the app launcher) offer the desktop entry's actions (freedesktop "Desktop Actions"). | written (`a3f7d92`) |
| F5 | The scroll wheel changes the volume and the brightness on their Control Center controls and their bar icons. | written (`94d8165`) |
| F6 | The accent colour follows KDE Plasma's. If MacShell can't set Plasma's accent, it points the user to KDE's settings and uses the accent from there. | written (`9031bcb`) |
| F7 | Better text anti-aliasing for the UI fonts, preferably with the same settings as KDE Plasma. | written (`a24a8ae`) |
| F8 | An adjustable screen corner radius, like a MacBook's physical screen. | written (`24997b9`) |

Statuses: `reported` / `requested` (nothing done yet), `fix written` (code committed, not run in Plasma), `needs diagnosis` (cause not established; what to collect is listed), `verified` (the user confirmed it in Plasma).

## State (2026-11-10, end of the second session)

- Every item except B5 has code on `pending-test`: 15 `wip` commits, **local only, not pushed, so CI has not run them**. None has run in Plasma. After a push, read the CI result at `https://api.github.com/repos/OngYean/MacShell-KWin/actions/runs?branch=pending-test`.
- **The bridge change for B6 (`kwin-bridge/main.cpp`) has never been compiled**: the development machine has no Qt headers. CI's build job is its first compile. If it fails, B6's Dock side (`72bcae0`) simply shows app icons.
- `README.md`'s list of changes from the original is updated for all of it (`AGENTS.md` §11 rule 15).
- Local checks used: `qmllint` 6.12 from the `PySide6-Essentials` wheel in a scratch virtualenv (syntax only; Quickshell imports show as warnings; `MacDock.qml` has two old `duplicated id` errors, `pillSes` and `navMa`), `sh` / `dash` for the script tests, `node` for `nix/test-kde-colors.js`, `python3 kwin-bridge/fake-bridge.py --selftest`.
- New CI steps: `nix/test-launch-app.sh`, `nix/test-macshell.sh`, `nix/test-kde-colors.js`, and the `After=` assertion for the Home Manager unit.
- Sources read for the findings: KWin and plasma-workspace `v6.8.2`, Quickshell `v0.3.2`, qtdeclarative `v6.12.0`, dbus `main`.
- New settings, all saved in `~/.config/macdock/settings.json` unless noted: `accentFromKde` (on), `nativeText` (off), `screenCornerRadius` (0), `minimizedSnapshots` (on); in `~/.config/macbar/settings.json`: `menuCascade` (off) and the `brightness` entry of `barWidgets` (off).

Suggested order on the Plasma host: B4 (rebuild, log out and in), B3, B1, B2, then F3, F4, F5, F1, F2, F6, F8, F7, and B6 last (it needs the new bridge).

## Done: cause, change, test

**B1 blur (`b58b299`).** `GlassBlur` looked for its window's `BlurCollector` among the children of the topmost item. Quickshell parents the window's content item to the `QQuickWindow` root item once the window exists (`ProxyWindowBase`), so no collector was found and no blur region was ever sent, the bar-strip fill included. It now searches every ancestor's children. Test: [`11`](11-kwin-blur-tests.md). The regions go over `ext-background-effect-v1`; KWin's own Blur reads them (`surface->blurRegion()`). If a third-party force-blur effect is the active blur and still shows nothing, note its name.

**B2 Dock size (`c69c2ed`).** Quickshell's icon provider is a pixmap provider, which Qt runs on the GUI thread, and KDE icon themes are SVG. Each slider step re-rendered every icon, twice per cell. Icon sizes are now requested in 64 px steps, and the hidden preview badge no longer loads. Test: drag Size and Magnification end to end. If it still freezes, the cause is elsewhere (not profiled).

**B3 Log Out (`8d2ab49`).** `org.kde.Shutdown` is D-Bus-activated. `dbus-send` without `--print-reply` exits at once, and dbus-daemon drops a call queued for a starting service when its sender is gone. Lock worked because KWin always owns `org.freedesktop.ScreenSaver`. Restart and Shut Down in the Apple menu had the same fault. Test all three. If Log Out still fails, run `dbus-send --session --print-reply --dest=org.kde.Shutdown /Shutdown org.kde.Shutdown.logout` in a terminal and keep `journalctl --user -b | grep -i -E 'shutdown|ksmserver'`. Known limits: KWin waits 10 s for windows to close, then sends a notification with "Cancel Logout" / "Log Out Anyway" and logs out after 2 minutes; MacShell shows no action buttons. Spotlight's Restart and Shut Down still call `systemctl` directly.

**B4 ordering cycle (`eccded9`).** `plasma-workspace.target` wants `macshell.service` and is ordered before `graphical-session.target`; the unit had `After=graphical-session.target`. It is now `After=plasma-core.target`, and CI asserts it. Test: rebuild, log in, `journalctl --user -b | grep -i 'ordering cycle'` is empty.

**F3 systemd units (`cf78ab7`).** On KDE, `hub.launch` (`shell.qml`) runs `assets/launch-app.sh`: `systemd-run --user` starts `app-macshell-<id>@<random>.service` in `app.slice` with `ExitType=cgroup`, and falls back to a direct start. The Dock, Spotlight and desktop `.desktop` icons use it. `sh nix/test-launch-app.sh` passes. Test: `systemctl --user list-units 'app-macshell-*'`, then `systemctl --user restart macshell` leaves the app running.

**F4 desktop actions (`a3f7d92`).** `MacBar.entryActions(entry)` feeds the Dock's right-click menu, Spotlight's result rows and a right-click menu in the application grid.

**B6 minimized windows as pictures (`3a9ac7b`, `72bcae0`).** KWin's `org.kde.KWin.ScreenShot2.CaptureWindow` has no caller check at `v6.8.2` and renders minimized windows. The bridge (0.3.0) takes one picture on a `snapshot` command and answers with a PNG `data:` URL of at most 256 px (decision record: [`kwin-bridge/README.md`](../kwin-bridge/README.md#window-snapshots-decision-record)). `KWinBackend` asks once when a window becomes minimized; the Dock gives each minimized window a cell next to the Trash with the picture and the app icon as a badge (Settings → Desktop & Dock → "Minimized windows as pictures", on by default). This corrects [`05`](05-kwin-port.md), which says KWin offers no capture to clients: true for Wayland protocols, not for this D-Bus interface. Test: minimize windows of a pinned and an unpinned app; the picture appears within a second; clicking it restores the window; `macshell-kwin-bridge --version` says 0.3.0; the NVIDIA GPU stays asleep. Known limit: the first minimize still flies to the app's icon, because the cell only exists afterwards.

**F1 menu width (`898b6b7`).** The dropdown is as wide as its longest row (260 to 640 px). Test with Dolphin's or Kate's long entries, near the right screen edge too.

**F2 submenus to the side (`df80830`).** Settings → Menu Bar → "Submenus open to the side", off by default so the tested drill-down is untouched. Each open submenu gets a panel beside its parent row; it opens on click or after 200 ms of hover. Test nested menus three levels deep, a menu near the right edge, and switching windows with a submenu open. Known limits: no keyboard navigation; panels are rebuilt when a level opens or closes.

**F5 scroll wheel (`94d8165`).** Every Control Center style slider and the Control Center's Display and Sound tiles follow the wheel (5 % per notch). New optional bar widget "Display brightness" (Settings → Menu Bar, off by default). The volume icon already scrolled.

**F6 accent (`9031bcb`).** "Follow KDE's accent color" (Appearance, on by default on KDE): MacShell reads Plasma's highlight colour from `kdeglobals` (`[Colors:Selection] BackgroundNormal`, else `[General] AccentColor`) and watches the file. A colour picked in MacShell is applied with `plasma-apply-colorscheme --accent-color`. Plasma tints the colour, so MacShell may settle on a slightly different shade than the swatch. Test both directions, and "From wallpaper" in KDE's settings.

**F7 text (`a24a8ae`).** "KDE's text rendering" (Appearance, off by default). The `macshell` launcher sets `QML_DISABLE_DISTANCEFIELD` when the saved setting is on, which makes Qt 6.12 use the system rasterizer (fontconfig, so KDE's font settings). It needs a restart of MacShell. Qt 6.12 has no `QT_QUICK_DEFAULT_TEXT_RENDER_TYPE` environment variable. Known limit: native text is soft wherever MacShell scales items, so at UI scales other than 100 % (Auto shrinks the UI on screens under 1920×1080 logical pixels). Judge it at 100 % and at your usual scale; if it is worse there, leave it off.

**F8 screen corners (`24997b9`).** "Screen corner radius" (Appearance, 0 to 40, 0 = off). Four small click-through Overlay surfaces per screen. Screenshots include them, and they block direct scan-out of fullscreen windows.

## Open

**B5 unlock: cause not found, nothing changed.** KWin hides every non-lock window while locked (`WindowItem::computeVisibility`) but keeps its last buffer, so an intact shell should reappear at once. An empty Dock and bar point to recreated windows (an output that went away and came back) or a restarted process. Collect right after an unlock:
- `systemctl --user status macshell` (did the PID or the start time change?) and `journalctl --user -b -u macshell | tail -50`;
- `macshell log | tail -50`;
- whether an external monitor was connected, whether the screen had turned off, and whether the laptop had slept.

Two things from the fixes above may change the picture: B4 (MacShell now starts with the session, so it is no longer started by hand) and F3 (apps no longer die with MacShell).

**Smaller gaps noticed on the way, not addressed:**
- Spotlight's "Restart" and "Shut Down" call `systemctl` directly instead of KDE's session manager.
- KWin's "these applications did not close" notification during logout has "Cancel Logout" / "Log Out Anyway" buttons; MacShell's banners show no action buttons, so a blocked logout waits KWin's 2 minutes.
- The tray menu still has a fixed width and drill-down submenus.
- Files opened through `xdg-open` are not started through `hub.launch`.
