# The Dock's magnification holds still while an icon's menu is open (2026-11-27)

`AGENTS.md` remains the authority. This file covers one feature request for branch `pending-test`.

**State: written as a `wip` commit on `pending-test`. qmllint shows no new findings and the `nix/test-*.js` checks pass; not run in Plasma or Hyprland.**

| ID | Request (user's words) | Status |
| --- | --- | --- |
| F28 | when right-click menu of a dock icon is visible, freeze the dock magnification animation (i.e. magnification temporarily does not follow cursor) so that the menu dont fly around when cursor is moved | change written (with a glide back to the pointer on close), untested |

## Before

The menu (and a folder's fan) follows its icon every frame (`ui.syncMenu`), and the icon moved for two reasons while the menu was open:

- `ui.mx`, the x the magnification centres on, still followed the pointer whenever it was in the icon row (`hh.point.position.y > ui.activeTop`). This code was already in the original MacShell.
- `ui.strength` dropped to 0 (icons back to rest) when the pointer left both the icon row and the menu, and came back when it returned.

## The change

`MacShell/MacDock.qml`, in `ui`:

- The `FrameAnimation` that copies `rawMx` to `mx` skips every frame while `menuOpen`.
- `openMenu()` records whether the Dock was magnified at that moment (`menuMagnified = active`). While the menu is open, `strength` uses that value, not `active`.
- `active` loses its "pointer over the open menu" clause. It only kept `strength` up while the menu was open, and `strength` no longer reads `active` then.

The Dock and Hyprland share this code, so it applies to both.

## Decisions and limits

- **Closing the menu with the pointer elsewhere on the Dock:** the magnification glides to the pointer instead of jumping there. `onMenuOpenChanged` sets `mxEaseLeft = 0.25` (seconds). For that long the `FrameAnimation` moves `mx` towards `rawMx` with a 50 ms time constant (`1 - exp(-frameTime / 0.05)` per frame, so the same speed at any refresh rate). Then it follows exactly again. A 600 px glide covers 99 % of the way and finishes with a 3–4 px step (simulated at 60 and 144 Hz).
- Dragging and the hover labels are unchanged. Labels were already hidden while a menu is open.

## Test plan (Plasma; Hyprland the same)

1. Magnification on. Right-click a Dock icon. Move the pointer along the Dock, over other icons → the icons don't magnify and shrink, and the menu stays put.
2. With the menu open, move the pointer up out of the Dock, beside the menu → the icons stay magnified and the menu doesn't drop.
3. Use a menu entry (for example New Window) → it works, and the menu closes.
4. Right-click an icon, move the pointer to another icon and click it → only the menu closes (as before: a click in the Dock's area with a menu open just closes the menu). The magnification glides under the pointer in about a quarter of a second, without a jump, and nothing gets stuck magnified. Moving the pointer during the glide doesn't make it stutter.
5. Right-click an icon, move the pointer above the Dock, beside the menu, and click there → the menu closes and the icons shrink back to rest.
6. A folder in the Dock: click it to open its stack, move the pointer along the Dock → the stack stays put.
7. Magnification off → nothing changes compared to before.
