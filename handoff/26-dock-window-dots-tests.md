# A dot per open window under Dock icons (2026-11-18)

`AGENTS.md` remains the authority. This file covers one request the user sent on 2026-11-18 for branch `pending-test`.

**State: written as a `wip` commit on `pending-test`. Linted with qmllint 6.12 (no new errors); not run in Plasma or on Hyprland.**

| ID | Request (user's words) | Status |
| --- | --- | --- |
| F26 | If there are multiple windows open under a desktop entry inside the dock, add an option to show multiple dots under the icon. This behavior should be on by default. | written, untested |

## How it works

- `rebuild()` in `MacShell/MacDock.qml` now counts the toplevels per Dock key (it only recorded "running" before) and gives each app item a `wins` count. The count is part of the Dock's change signature, so opening or closing a second window redraws the dots.
- The single indicator `Rectangle` became a `Row` of dots: `min(wins, 3)` when `multiIndicators` is on, 1 when it is off.
- Setting `multiIndicators` (default `true`), saved in `~/.config/macdock/settings.json`, reset by "Reset MacShell". Its switch, "Show a dot for each open window", sits under "Show indicators for open applications" in Settings → Desktop & Dock and is hidden while that one is off. Spanish and Russian strings added.

## Decisions and limits

- **At most three dots,** so the row is never wider than a small icon (3 × 4 px + 2 × 3 px gaps = 18 px).
- **Every window counts:** minimized ones and those on other virtual desktops, the same list the Dock already uses for "running".
- Window cells (previews next to the Trash) have no dots, as before.

## Test plan (Plasma, then Hyprland if available)

1. Fresh settings: open one Dolphin window → one dot. Open a second → two dots. A third and a fourth → three dots. Close windows one by one → the dots go down to one, then none.
2. Same with an app that is not pinned (it appears after the separator).
3. Minimize one of two windows → still two dots. Move one to another virtual desktop → still two dots.
4. Settings → Desktop & Dock: turn "Show a dot for each open window" off → one dot for every running app. Turn "Show indicators for open applications" off → no dots, and the new switch is hidden.
5. Restart MacShell → the switch keeps its state. "Reset MacShell" (About) → it is on again.
6. Light and dark Dock: the dots have the same colour as the old single dot and sit at the same height.
