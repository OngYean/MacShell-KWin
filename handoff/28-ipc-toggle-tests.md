# Control Center and notification centre IPC (2026-11-26)

`AGENTS.md` remains the authority. This file covers one request for branch `pending-test`.

**State: written as a `wip` commit on `pending-test`. qmllint reports no syntax errors in `MacBar.qml` or `shell.qml`. Not run in Plasma or Hyprland.**

| ID | Request | Status |
| --- | --- | --- |
| F27 | Add `controlcenter toggle`, correct `controlcenter open`, add `notifications toggle`. | written, untested |

## What was wrong

An audit of every `ipc call` in the repository against the `IpcHandler`s found:

- `controlcenter open` and `controlcenter toggle` both sent `ccRequest(true)`, and the receiver toggled. So `open` closed an open Control Center. `controlcenter close` set the bar's popover to none, closing whatever popover was open, not only the Control Center.
- `notifications open` called `openPop("notif")`, which closes the panel if it is already showing. There was no `notifications toggle`.
- `deps open` and `windecor toggle|on|off` are mentioned (in `Installer.qml`, `WindowDecor.qml` and the Hyprland installer's button) but nothing creates those components, already in upstream `51db0ba`. Left alone: the Installer is Hyprland-only and `WindowDecor` would compete with Klassy.

## The change

`MacBar.qml`: `ccRequest` and `notifPopRequest` now carry `"open"`, `"close"` or `"toggle"` instead of a bool, and the bar that serves the focused screen acts on it: `open` opens if closed, `close` closes only that panel, `toggle` switches. `shell.qml`: the `notifications` target gains `toggle`. The IPC targets are the only senders of either signal.

## Test plan (Plasma)

Restart MacShell (`systemctl --user restart macshell`), then:

1. `macshell ipc call controlcenter open` twice → it opens and stays open.
2. `macshell ipc call controlcenter toggle` twice → it closes, then opens.
3. Open a menu-bar popover (e.g. the clock's calendar), then `macshell ipc call controlcenter close` → the calendar stays open.
4. `macshell ipc call controlcenter close` with the Control Center open → it closes.
5. Repeat 1, 2 and 4 with `notifications` → same behaviour for the notification centre.
6. `macshell ipc call notifications open` with the Control Center open → the notification centre replaces it.
7. Bind `notifications toggle` to a key in System Settings → Keyboard → Shortcuts → it opens and closes with the same key.
8. With two screens: focus a window on the second screen and run `controlcenter toggle` → it opens on the focused screen.
