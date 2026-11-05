# Test plan: replacing `plasmashell` is the default

`AGENTS.md` remains the authority, and [`06-kwin-testing-guide.md`](06-kwin-testing-guide.md) has the general runbook. On 2026-11-05 the user asked for running MacShell **in place of** `plasmashell` to be the default launch, with running side by side as the second option. This depends on [`10`](10-replace-wallpaper-splash-tests.md): MacShell draws the wallpaper and ends the login splash when `plasmashell` doesn't run.

Written on macOS without Nix or Plasma. `sh nix/test-macshell-session.sh` passes there (macOS `sh` and `dash`; stand-in commands only). ShellCheck, the Home Manager evaluation in CI and **every check below have not been run**.

## What changed

- **`macshell-session`:**
  - `start` replaces `plasmashell` for the current login; `replace` is an alias.
  - `coexist` runs MacShell next to `plasmashell`, starting it again if needed; `restore` is an alias.
  - `stop` now also brings `plasmashell` back in Plasma, so a session is never left without a shell.
- **Home Manager:** `programs.macshell.mode` is `"replace"` by default. It only has an effect with `autostart = true`. Then:
  - `systemd.user.sessionVariables.MACSHELL_KDE_MODE = "replace"` puts the variable in the user manager's environment for every login, through `environment.d`.
  - `~/.config/systemd/user/plasma-plasmashell.service.d/macshell.conf` adds `ConditionEnvironment=!MACSHELL_KDE_MODE=replace`. `plasma-core.target` only *wants* the unit, so a skipped `plasmashell` doesn't hold up the session.
  - `macshell.service` gives up after 3 failures in 60 s. Its `OnFailure=macshell-fallback.service` then unsets the variable and starts `plasmashell`, but only while `graphical-session.target` is active, so not during logout.
- **Why a condition and not a mask:** nothing is disabled. `macshell-session coexist` and `stop` work for the current login, and `mode = "coexist"` or `autostart = false` returns to the normal login after a rebuild.

## 1. The session command (no rebuild needed)

From the branch: `nix run .#macshell-session -- <command>`. Or install the package from this branch. If Home Manager already installed `macshell.service`, the command restarts that unit, which runs the *installed* MacShell. That is fine for these checks, which are about switching `plasmashell`.

1. `start`:
   - `systemctl --user is-active plasma-plasmashell` reports `inactive`;
   - MacShell runs, with its wallpaper;
   - `busctl --user status org.freedesktop.Notifications | grep -E '^(PID|Comm)='` names Quickshell.
2. `coexist`: `plasmashell` is back with its panels and desktop, and MacShell runs next to it.
3. `stop`: MacShell is gone and `plasmashell` runs.
4. `replace` and `restore` behave like `start` and `coexist`.

## 2. Login without `plasmashell` (Home Manager)

1. Enable `programs.macshell.autostart = true;` and leave `mode` unset. Rebuild, then check:
   - `systemctl --user cat plasma-plasmashell.service` ends with the `macshell.conf` drop-in;
   - `cat ~/.config/environment.d/10-home-manager.conf` contains `MACSHELL_KDE_MODE=replace`.
2. Log out and in. **Expected:**
   - the splash screen closes in a few seconds, not 30;
   - MacShell's bar, Dock and wallpaper appear;
   - `systemctl --user status plasma-plasmashell` shows it was skipped (`ConditionEnvironment=!MACSHELL_KDE_MODE=replace was not met`);
   - `macshell-session status` reports `MACSHELL_KDE_MODE (user manager): replace`.
3. The session is otherwise normal:
   - KWin and Klassy decorations;
   - `Meta+L` locks, and unlocking works;
   - a Polkit prompt appears (for example `pkexec true`);
   - `notify-send` shows a MacShell banner;
   - screenshots and screen sharing still work;
   - Bluetooth and network toggles work.
4. From KRunner (`Alt+Space`), run `macshell-session coexist`. `plasmashell` starts, and MacShell keeps running next to it.
5. Log out and in again. MacShell replaces `plasmashell` again.

## 3. Fallback when MacShell keeps failing

This uses a runtime override, which is gone after a reboot:

```sh
d="$XDG_RUNTIME_DIR/systemd/user/macshell.service.d"; mkdir -p "$d"
printf '[Service]\nExecStart=\nExecStart=/bin/sh -c "exit 1"\n' > "$d/fail.conf"
systemctl --user daemon-reload && systemctl --user restart macshell.service
sleep 15; systemctl --user is-failed macshell.service; systemctl --user is-active plasma-plasmashell.service
```

**Expected:** `failed`, then `active`. `plasmashell` came back by itself. Clean up afterwards:

```sh
rm "$d/fail.conf"; systemctl --user daemon-reload; systemctl --user reset-failed macshell.service
```

## 4. Coexist at login, and rollback

1. Set `programs.macshell.mode = "coexist";`, rebuild, then log out and in. **Expected:** `plasmashell` starts and MacShell runs next to it. The drop-in and the variable are gone.
2. With `autostart = false` (or the module removed), the next login is plain Plasma.

## Results

| Check | Result (`pass` / `fail` / `partial`) | Evidence |
| --- | --- | --- |
| 1. `start` / `coexist` / `stop` / aliases | | |
| 2. Login without `plasmashell`: splash, shell, skipped unit | | |
| 2. Session services (lock, Polkit, notifications, screenshots, sharing) | | |
| 2. `coexist` from KRunner, next login replaces again | | |
| 3. Fallback brings `plasmashell` back | | |
| 4. `mode = "coexist"` login; `autostart = false` rollback | | |

Treat the feature as complete only after these pass (AGENTS.md §12).
