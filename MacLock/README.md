# MacLock Hyprland IPC integration

MacLock has a dedicated Quickshell IPC endpoint, `lockscreen.lock`. The helper `lock-via-ipc.sh` makes the keybind self-starting: it starts an IPC-capable MacLock instance if needed, waits for it to become ready, then requests the lock. Each lock process exits after unlock; the helper starts a fresh one for the next lock because a Wayland session-lock object should not be reused.

## Install

Copy this `MacLock` directory to `~/.config/quickshell/MacLock/` so `shell.qml` is at `~/.config/quickshell/MacLock/shell.qml`.

To lock before suspend (including the usual laptop lid-close action), run:

```sh
sh ~/.config/quickshell/MacLock/enable-sleep-lock.sh
```

The MacShell Hyprland module runs this setup automatically at compositor startup. It adds MacLock to Hypridle's
`before_sleep_cmd`, keeps any existing Hypridle settings and pre-sleep command, creates a one-time backup of the
original config, and restarts Hypridle to apply the change. This covers lid close when the system's logind policy
actually suspends on lid close; if lid close is configured to do nothing, change that system power policy too.

In your Lua-driven Hyprland config, add:

```lua
hl.bind("SUPER + L", hl.dsp.exec_cmd("sh ~/.config/quickshell/MacLock/lock-via-ipc.sh"))
```

This uses the `hl.bind` / `hl.dsp.exec_cmd` style. Change `SUPER + L` if that key is already used, and adjust the helper path if you installed MacLock elsewhere.

Spotify tracks that expose a Spotify track URI or `open.spotify.com/track/...` URL can use the track's looping Canvas
video as the animated background in expanded artwork mode. Other tracks continue to use their album artwork. Lyrics
prefer synchronized NetEase/LRCLIB results and use Genius as a plain-text fallback; Genius lyrics are not time-synced.

## Direct IPC

If an IPC-capable MacLock instance is currently running, the direct IPC command is:

```sh
qs -c MacLock ipc call lockscreen lock
```

The helper launches the IPC-capable process with `MACLOCK_DAEMON=1`. Existing setups that run `qs -c MacLock` directly (for example from `maclock.sh`/hypridle) keep the original one-shot behavior: the session locks immediately and MacLock exits after unlock.

Preview mode is unchanged: `MACLOCK_PREVIEW=1 qs -c MacLock` opens the visual preview and does not request a real lock.

## KDE Plasma

KWin has no `ext-session-lock` protocol, so `shell.qml` cannot lock a Plasma session. There MacLock is the screen
KDE's own locker shows: `kde/build.sh <dir>` assembles the Plasma/Shell package `com.macshell.lock`, whose
`lockscreen/LockScreen.qml` KDE loads once per screen. KDE still locks the session and checks the password.

| Path | What it is |
| --- | --- |
| `LockScreen.qml` and the files next to it | The UI, shared by both. It imports no Quickshell module. |
| `Host.qml`, `Run.qml`, `JsonFile.qml` | The Quickshell side of what the UI needs from the session: battery, media player, helper processes, watched files. |
| `kde/ui/` | The same three files for KDE's lock screen (plus `HostPlayers.qml`), laid over the ones above in the package. |
| `kde/lockscreen/LockScreen.qml` | The file KDE loads. |
| `kde/lockscreen/LockState.qml` | The state all screens share, and the password flow against KDE's authenticator: what `shell.qml` is on Hyprland. |

Nix: `packages.macshell-lock`, switched on by `programs.macshell.lockScreen` (see the top-level README).
`sh nix/test-lock-screen.sh` loads both sides against stand-ins for KDE's and Quickshell's modules.
