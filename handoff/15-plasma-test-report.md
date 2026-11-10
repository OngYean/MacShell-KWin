# Plasma 6.8 test report (2026-11-10): bugs and feature requests

`AGENTS.md` remains the authority. This file is the shared list of what the user found when running branch `pending-test` on a real KDE Plasma 6.8 Wayland session **with `plasmashell` disabled** (Home Manager `autostart = true`, `mode = "replace"`), and of the features they asked for. Work on it happens on `pending-test`, one commit per item.

Each item has an ID. Use it in commit bodies and when reporting test results.

## Reported bugs

| ID | Report (user's words, shortened) | Status |
| --- | --- | --- |
| B1 | With "Use KWin's blur" on, the shell's surfaces turn transparent but nothing is blurred behind them. MacShell's Settings window does get force blur on its side panel. | reported |
| B2 | MacShell freezes for 5–10 s when the Dock size is changed in Settings. | reported |
| B3 | Log Out from the top-left menu does nothing. Plasma has its own session implementation, and some `loginctl` commands have quirks there. | reported |
| B4 | `plasma-workspace.target: Found ordering cycle: macshell.service/start after graphical-session.target/start after plasma-workspace.target/start after macshell.service`. The splash screen stays for a long time, then a Plasma session without a shell starts. | reported |
| B5 | After unlocking, MacShell takes a while to bring its elements back. Until then the Dock has no icons, and neither has the top bar. | reported |
| B6 | In the Dock, a minimized window should show a small snapshot of itself as its icon by default, as on macOS. | reported |

## Requested features

| ID | Request | Status |
| --- | --- | --- |
| F1 | The global menu's popover grows wider to fit its text, so labels are not cut off with "…". | requested |
| F2 | An option to open a submenu to the right of its parent menu, instead of replacing the menu with a "back" entry. | requested |
| F3 | Start applications as systemd units where possible, not as children of the MacShell process. | requested |
| F4 | The Dock icon's right-click menu and Spotlight (the app launcher) offer the desktop entry's actions (freedesktop "Desktop Actions"). | requested |
| F5 | The scroll wheel changes the volume and the brightness on their Control Center controls and their bar icons. | requested |
| F6 | The accent colour follows KDE Plasma's. If MacShell can't set Plasma's accent, it points the user to KDE's settings and uses the accent from there. | requested |
| F7 | Better text anti-aliasing for the UI fonts, preferably with the same settings as KDE Plasma. | requested |
| F8 | An adjustable screen corner radius, like a MacBook's physical screen. | requested |

Statuses: `reported` / `requested` (nothing done yet), `fix written` (code committed, not run in Plasma), `needs diagnosis` (cause not established; what to collect is listed), `verified` (the user confirmed it in Plasma).

The sections below are filled in as each item is worked on: cause, what changed, and how to test it.
