# Swiping a notification popup away dismisses it (2026-11-27)

`AGENTS.md` remains the authority. This file covers one feature request for branch `pending-test`.

**State: written as a `wip` commit on `pending-test`. qmllint shows no new findings; not run in Plasma or Hyprland.**

| ID | Request (user's words) | Status |
| --- | --- | --- |
| F29 | add swiping for notification popups, swiping a notification away from the screen view means dismissing it | change written, untested |

## The change

`MacShell/MacBar.qml`, in the popup delegate (`toast`, under "notification popups"):

- `swipeX` shifts the glass slab (`tslab.x`); the content, the border and the click area follow it. The popup fades as it moves (`opacity` × `1 - swipeX / width`).
- A `DragHandler` (x axis only, `target: null`) inside the popup's `MouseArea` drives `swipeX` with the pointer. It sits inside the `MouseArea` so it sees the press first; once the drag passes Qt's drag threshold it takes the grab and the `MouseArea`'s click (open the app) is cancelled.
- A `WheelHandler` on the same `MouseArea` drives it with horizontal touchpad scrolling. Mostly vertical scrolls are ignored. The gesture ends 160 ms after the last scroll event (`wheelRest`).
- On release: past a third of the popup's width, or flicked right faster than 800 px/s, `swipeX` animates off the screen and `toast.dismiss()` runs, the same call as the close button. Otherwise it springs back to 0. Leftwards the card only moves a quarter of the distance (rubber band).
- The popup's auto-dismiss timer pauses while it is being swiped.

The bar's code is shared, so this applies on Hyprland too.

## Decisions and limits

- **"Dismiss" = the close button's dismiss:** the popup goes away but the notification stays in the notification centre, as on macOS. Deleting it from there is still the centre's own close button.
- **Touchpad direction:** the card should follow the fingers. Qt reports `inverted` for natural scrolling, and the code flips the delta when it is not set. If Qt Wayland does not get the scroll direction from KWin, natural-scrolling users will see the card move against their fingers (step 4). Then the sign in `onWheel` needs to follow the touchpad setting instead.
- Swiping only to the right, towards the screen edge the popups sit against.

## Test plan (Plasma; Hyprland the same)

1. Send a notification (`notify-send Test hello`). Drag the popup slowly to the right by less than a third of its width and let go → it springs back and the app is not activated. It still disappears on its own after a few seconds.
2. Drag it right past a third and let go → it slides off the screen and disappears; the popups below glide up. The notification is still listed in the notification centre (bell).
3. A short fast flick to the right → dismissed as in 2.
4. Two-finger swipe right on the touchpad over a popup, with natural scrolling on and then off (System Settings → Touchpad → Invert scroll direction) → in both cases the card follows the fingers and is dismissed past a third. Report which setting, if any, moves it the wrong way.
5. Scroll vertically over a popup → it does not move sideways.
6. Drag left → it moves only a little and springs back.
7. Click a popup without dragging → the app is activated, as before. The close button (hover) still works.
8. Hold a popup half swiped (pointer still pressed) for longer than its timeout → it does not disappear under the pointer.
