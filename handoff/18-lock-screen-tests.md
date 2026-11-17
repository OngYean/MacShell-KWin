# MacLock as KDE's lock screen (2026-11-16)

`AGENTS.md` remains the authority. This file covers one request the user sent on 2026-11-16 for branch `pending-test`: theme Plasma's lock screen with this project's one, replacing Plasma's lock screen only if needed.

**State: written and pushed to `pending-test` on 2026-11-16 as `wip` commits. Nothing has run in Plasma or in Hyprland. The option is off by default.**

| ID | Request (user's words) | Status |
| --- | --- | --- |
| F15 | Theme Plasma's lock screen with this project's one, replacing Plasma's built-in lock screen if needed. | written, untested |

## Decision: KDE keeps locking, MacLock is what it draws

Three routes were checked against the 6.8.2 sources of KWin, kscreenlocker, libplasma, plasma-workspace and plasma-desktop:

| Route | Result |
| --- | --- |
| Run `MacLock/shell.qml` as it is (`WlSessionLock`) | Not possible: KWin 6.8.2 has no `ext-session-lock` implementation. |
| Replace the `kscreenlocker_greet` binary with a Quickshell wrapper | Rejected. It needs a system-level package override, loses fingerprint and smartcard, and any clean exit of the wrapper unlocks the session (`ksldapp.cpp:182`). It also goes against `AGENTS.md` §6 ("Keep KDE's native screen-locking"). |
| A Plasma/Shell package that holds only `lockscreen/LockScreen.qml` | **Chosen.** KDE's locker loads its screen from the shell package (`greeterapp.cpp:502`, `shellpackage.cpp:64`). |

What this keeps from KDE: the PAM check (service `kde`, plus fingerprint, smartcard, face, U2F), locking on idle and before sleep, the grace period, the restart after a crash and the emergency screen. Two properties matter for safety:

- The screen's `Qt.quit()` only unlocks after the authenticator has succeeded (`greeterapp.cpp:316`). A bug in MacLock's QML cannot unlock the session.
- If the screen's QML fails to load, KDE loads its built-in fallback screen (`greeterapp.cpp:364`). A bug cannot lock the user out.

## How it is built

- **`MacLock/LockScreen.qml` no longer imports Quickshell or QtMultimedia.** What it needs from the session sits behind three components with two implementations each:

  | Component | Quickshell side (`MacLock/`) | KDE side (`MacLock/kde/ui/`) |
  | --- | --- | --- |
  | `Host.qml`: battery, current media player, position and seek, IPC to the shell | UPower, Mpris, `qs -c MacShell ipc call` | `/sys/class/power_supply`, `HostPlayers.qml` (KDE's `Mpris2Model`), `macshell ipc call` |
  | `Run.qml`: one helper process | `Process` | Plasma's `executable` data engine (`org.kde.plasma.plasma5support`) |
  | `JsonFile.qml`: a file's text, kept current | `FileView`, watched | `cat` every 2 s |

  The two video backgrounds moved to `VideoLoop.qml`, loaded by URL, so a session without QtMultimedia keeps the still wallpaper instead of failing to load.
- **`MacLock/kde/lockscreen/LockScreen.qml`** is the file KDE loads, once per screen. It shows `ui/LockScreen.qml` and hands KDE's `authenticator`, user name and avatar to the shared state.
- **`MacLock/kde/lockscreen/LockState.qml`** is a QML singleton (KDE's own `PasswordSync` works the same way): the state every screen's view shares, and the password flow. It is what `shell.qml`'s `lockState` and `PamContext` are on Hyprland.
- **`MacLock/kde/build.sh <dir>`** assembles the package `com.macshell.lock`: `metadata.json`, `contents/lockscreen/` (the two files above and a `qmldir`), and `contents/lockscreen/ui/` (MacLock's files with `kde/ui/` laid over them). The package falls back to `org.kde.plasma.desktop` for everything else (`X-Plasma-FallbackPackage`).
- **Nix:** `packages.macshell-lock`, and `programs.macshell.lockScreen` (default `false`), which links the package into `~/.local/share/plasma/shells/` and sets `PLASMA_DEFAULT_SHELL=com.macshell.lock` in the session environment.
- **Settings → Lock Screen under KWin:** "Lock Screen Now" calls KDE's locker; "Preview" is hidden (it starts MacLock's Quickshell entry point, which cannot run under KWin).

## Decisions and their reasons

- **Selected by `PLASMA_DEFAULT_SHELL`, not by writing `plasmashellrc`.** The variable is how the module already steers the session (`MACSHELL_KDE_MODE`), it leaves no state behind in a file Plasma owns, and turning the option off undoes it. The cost: `plasmashell` (`shellcorona.cpp:2992`) and the logout screen (`logout-greeter/main.cpp:32`) read the same variable. Both should fall back to Plasma's package for every file; that is untested (test 11).
- **The password flow holds a password typed before PAM asks.** KDE's authenticator drops an answer when no prompt is pending (`pamauthenticator.cpp:147`), and its own screen only shows the field after the prompt. MacLock's field is always there, so `LockState.qml` keeps the text until the prompt arrives.
- **A failure only counts as a wrong password if one was sent**, because the authenticator also reports failures of its own (timeouts) and of the fingerprint reader.
- **Success without any prompt (an account with no password) waits for Enter**, as KDE's "Unlock" button does.
- **Private Plasma modules are optional at run time.** `org.kde.plasma.private.mpris` (Now Playing) is loaded through a `Loader`, `org.kde.plasma.private.keyboardindicator` (Caps Lock) through `Qt.createQmlObject`. If a Plasma update changes them, the feature disappears and the screen still loads. `org.kde.plasma.plasma5support` is required: without it KDE's fallback screen shows.
- **No `jq` for settings.** The lock screen runs in KWin's environment, not MacShell's wrapper, so `LockState.qml` reads MacShell's JSON with `cat` and parses it in QML. Lyrics still use the upstream script, which needs `jq`, `curl` and `python3`.
- **Helper programs use the network; the lock screen's QML cannot.** KDE gives the lock screen a network manager that refuses everything. Lyrics and Spotify Canvas already ran as helper processes, and remote album covers are now downloaded the same way (`HostPlayers.qml`, cached for 7 days in `~/.cache/maclock/art`). This is a deliberate way around KDE's rule for these three features; remove the `Run` calls to undo it.
- **The full layout goes on MacShell's Main display**, else the built-in panel, else the first screen Qt lists (changed on 2026-11-17, see [`24`](24-plasma-report-3.md); it was the first screen Qt lists). Hyprland uses the focused monitor, which KDE's lock screen is not told.

## What was checked

- `sh nix/test-lock-screen.sh` passes on the macOS dev box with Qt 6.12 from the PySide6 wheel (a small Python stand-in for Qt's `qml` tool). It loads the assembled package the way KDE does, against stand-ins for KDE's authenticator, `executable` engine and `Mpris2Model`, and walks: settings parsed, wallpaper picked, a password sent before and after the prompt, a wrong password, a failed fingerprint read, success without a prompt, unlock. It also loads the Quickshell side against stand-ins for Quickshell's modules. With the early-password hold removed, the test fails.
- `qmllint` 6.12 on `LockScreen.qml` and `MacDock.qml`: no new findings compared with `266f7c3`. No errors in the new files.
- `sh -n` on the two new scripts; the workflow file parses as YAML.
- CI did not run for the push (`cd3eac0`): GitHub did not start the job because the account is locked over a billing issue, as for every push since 2026-11-10. So the Nix build of `macshell-lock`, the Home Manager evaluation with `lockScreen = true`, `shellcheck` on the two new scripts and the load checks under Nix's `qml` tool have not run anywhere.
- **Not checked:** anything in a Plasma session; whether the stand-ins match the real modules; the Hyprland path (the refactor changed its files and it has no test machine); `shellcheck`, the Nix build and the module evaluation (no Nix on the dev box, and no CI).

## Test plan (NixOS, Plasma 6.8, Wayland)

Before starting, open a text console once (Ctrl+Alt+F3), log in, and leave it. If the lock screen ever cannot be unlocked: `loginctl` there lists the sessions, `loginctl unlock-session <id>` unlocks (KDE honours it, `ksldapp.cpp:183`).

**In a window, nothing locked (do this first):**

1. Update the flake input and rebuild with `programs.macshell.lockScreen = true;`. Do not log out yet. This rebuild is the first time `macshell-lock` and the module change are built at all: if it fails, send the error.
2. Start the lock screen in a window:
   ```sh
   greet=$(nix-store -qR /run/current-system | grep -m1 -E -- '-kscreenlocker-[0-9][^/]*$')/libexec/kscreenlocker_greet
   "$greet" --testing --shell com.macshell.lock 2>&1 | tee /tmp/maclock-greeter.log
   ```
   Expected: MacLock's screen (large clock, glass, your wallpaper). KDE's plain fallback instead means the QML failed: send `/tmp/maclock-greeter.log`. If `$greet` is empty, find the binary with `ls /nix/store/*-kscreenlocker-*/libexec/kscreenlocker_greet`.
3. In that window: a wrong password shows "Incorrect password" and empties the field; the right one closes the window. Note any `ReferenceError`, `TypeError` or "is not installed" lines in the log (the last one for `private.mpris` or `private.keyboardindicator` means that feature is missing, not a failure).

**Locked for real:**

4. This should print nothing (a value here overrides the variable):
   ```sh
   kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage
   ```
5. Log out and in. The variable must have reached KWin:
   ```sh
   tr '\0' '\n' < /proc/$(pgrep -x kwin_wayland | head -n1)/environ | grep PLASMA_DEFAULT_SHELL
   ```
   If it prints nothing, MacLock will not show; as a stopgap `kwriteconfig6 --file plasmashellrc --group Shell --key ShellPackage com.macshell.lock` applies at the next lock (undo with `--delete`), and report it.
6. Lock with Meta+L, with the Apple menu's Lock Screen, and with Settings → Lock Screen → Lock Screen Now. MacLock shows each time. Wrong password, then the right one.
7. Lock, and type the password and Enter immediately, before anything else: it unlocks (the held password).
8. Fingerprint, if enrolled: lock, press a key, touch the reader: it unlocks.
9. Two screens: the full layout is on the primary one, the other shows wallpaper and clock, and typing works wherever the pointer is.
10. Idle lock and lock before sleep (close the lid, or `systemctl suspend`): MacLock shows on wake.
11. `plasmashell` and the logout screen with the variable set: `macshell-session coexist` brings `plasmashell` up with its panels and desktop as usual, and Log Out shows Plasma's normal confirmation screen. Then `macshell-session start`.

**Features on the screen:**

12. Play music, lock: Now Playing shows title, artist and cover (a Spotify cover is downloaded, so it may take a moment); play/pause, next and the scrubber work. The lyrics button shows lyrics if `jq`, `curl` and `python3` are on your `PATH`.
13. A notification arriving while locked appears within about 2 s; a running Clock timer shows and counts.
14. Battery, Wi-Fi, and the Caps Lock hint are right. The clock follows Settings → Lock Screen → Clock (lock again after changing it).
15. With a video wallpaper set in MacShell: it plays behind the lock screen. A still wallpaper there instead means QtMultimedia is not visible to the lock screen; report it (the likely fix is `kdePackages.qtmultimedia` in the user or system packages).

**Recovery:**

16. While locked, from the text console: `pkill -9 -f kscreenlocker_greet`. The session stays locked and the lock screen comes back.
17. A broken package, in a window: `cp -rL ~/.local/share/plasma/shells/com.macshell.lock /tmp/broken && chmod -R u+w /tmp/broken && echo 'this is not QML' >> /tmp/broken/contents/lockscreen/LockScreen.qml`, then `"$greet" --testing --shell /tmp/broken`. Expected: KDE's fallback screen, and your password closes it.
18. `lockScreen = false`, rebuild, log out and in: KDE's own lock screen is back.

**Hyprland (if a machine is available):** `MacLock` still locks and unlocks, shows the battery, Now Playing with a working scrubber, lyrics, notifications and a video wallpaper. Those are the paths the refactor moved into `Host.qml`, `Run.qml`, `JsonFile.qml` and `VideoLoop.qml`.

## Known limits

- **Missing from KDE's own screen:** Switch User, Sleep and Hibernate buttons, the on-screen keyboard, the keyboard layout switcher, and the chooser between authenticators. System Settings → Screen Locking → Appearance has no effect.
- **Wallpaper:** only MacShell's pick (`wallpaperPath` in `~/.config/macbar/settings.json`, then `macdock`). Next to `plasmashell` with no pick the background is dark; Plasma's own wallpaper is not read.
- **Entrance:** it fades in over KDE's own lock wallpaper, which KDE draws under the screen (not over black, as this brief first said). From 2026-11-17 MacShell keeps that wallpaper the same picture as its own, see [`24`](24-plasma-report-3.md).
- **Polling:** notifications and the Clock state every 2 s (`shortcut:` comment in `kde/ui/JsonFile.qml`), the battery every 30 s, Wi-Fi once per lock.
- **Spotify Canvas** is looked up by artist and title only; KDE's player model does not pass the track id on.
- **No preview and no `MACLOCK_*` overrides** under KDE.
- **Messages are not translated** beyond MacLock's own small table, as on Hyprland.
- **`install.sh`** copies `MacLock/kde/` to `~/.config/quickshell/MacLock/kde/` on Hyprland, where nothing loads it.
- **Possible follow-up:** run the real `kscreenlocker_greet --testing` under the headless KWin of `nix/kwin-smoke.sh` in CI, so the real Plasma modules are loaded without the user's machine.
