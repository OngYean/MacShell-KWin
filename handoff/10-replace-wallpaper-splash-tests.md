# Test plan: branch `kwin-replace-wallpaper-splash`

`AGENTS.md` remains the authority, and [`06-kwin-testing-guide.md`](06-kwin-testing-guide.md) still has the general runbook and rollback. This branch is the first step towards running MacShell **without `plasmashell`**. The user chose to go that way on 2026-11-05, because MacShell's desktop layer and Plasma's desktop can't share the screen. It covers two things `plasmashell` did that nothing else did:

1. **Wallpaper.** `plasmashell` draws it. MacShell's picker handed the image to `plasmashell`, or else to `awww` / `swww`, which aren't installed. The result was a black background.
2. **Login splash.** KSplash closes at its sixth stage. `plasmashell` sends the last one (`desktop`, `shell/shellcorona.cpp` in plasma-workspace 6.8.2). Without it the splash only closes on its 30 s timeout (`ksplash/ksplashqml/splashwindow.cpp`).

Both were written on macOS without Nix, Quickshell or Plasma. **Nothing has been run in Plasma, and the QML has not been linted** (no `qmllint` on the development machine).

## What changed

- `MacShell/backends/compositor/Compositor.qml`: `desktopUnserved` is true on KWin once the bridge has reported the session and `plasmashell` is not running.
- `MacShell/Wallpaper.qml` (new, created in `shell.qml`) is active only while `desktopUnserved` is true. On each screen it draws `MacDock.wallpaperFor()`: your last pick in MacShell's picker, or else the picture in Plasma's `plasma-org.kde.plasma.desktop-appletsrc`. It uses a Background layer surface with the namespace `desktop`, which KWin turns into a Desktop window, as Plasma's is. The surface never takes the pointer. Once the picture has loaded, or after 3 s at most, it runs `busctl --user --auto-start=no call org.kde.KSplash /KSplash org.kde.KSplash setStage s desktop`.
- `MacShell/MacBar.qml`: while `desktopUnserved` is true, the wallpaper picker no longer starts a wallpaper program. `Wallpaper.qml` shows the pick.

## Setup

```sh
git fetch && git switch kwin-replace-wallpaper-splash && git pull
nix develop --command true                 # warm the dev shell, so later start-up times are not skewed by evaluation
macshell kill 2>/dev/null                  # stop an installed MacShell, if any
```

**Rollback at any point:**
1. `Ctrl+C` (or `pkill -f 'qs -p'`) to stop MacShell.
2. `systemctl --user start plasma-plasmashell.service` to bring Plasma back.
3. If that fails, log out and back in.

Nothing on this branch writes Plasma, KWin or KSplash configuration.

Sharing results: share pass/fail, timings, `[wallpaper]` log lines and QML warnings. Don't share screenshots of private windows.

## 1. Wallpaper without `plasmashell`

1. Start MacShell next to `plasmashell`: `nix develop --command qs -p ./MacShell`. **Expected:** nothing looks different from before.
2. In another terminal: `systemctl --user stop plasma-plasmashell.service`. **Expected:** within about a second a wallpaper appears where Plasma's was. It is your last MacShell pick, or else Plasma's picture.
3. Desktop icons, desktop widgets and the right-click desktop menu still work on top of it.
4. Pick another picture in MacShell's wallpaper picker. **Expected:**
   - it shows straight away;
   - the log has `[wallpaper] applied with: MacShell (KDE without plasmashell)`;
   - no "Could not set it" notification appears;
   - `pgrep -a 'awww|swww|mpvpaper|swaybg'` prints nothing.
5. Check that the picture is sharp at your display scale, and on every screen if more than one is connected.
6. Overview (`Meta+W`) and Show Desktop treat it like Plasma's wallpaper.
7. The Dock's and bar's Liquid Glass show the same picture.
8. Start Plasma again with MacShell still running: `systemctl --user start plasma-plasmashell.service`. **Expected:** Plasma's desktop returns, and MacShell's wallpaper surface goes away, with no doubled or flickering wallpaper. Known limit: if MacShell took notifications in the meantime (the 15 s rule), Plasma gets none until you stop MacShell and restart `plasmashell`.

## 2. Login splash

This simulates the end of a login. The splash covers the whole screen, so paste the whole block at once. It closes by itself after 30 s at most.

```sh
systemctl --user stop plasma-plasmashell.service; pkill -f 'qs -p' ; sleep 1
ksplashqml & pid=$!; sleep 1                                   # sets initial, kcminit, wm
busctl --user call org.kde.KSplash /KSplash org.kde.KSplash setStage s startPlasma
busctl --user call org.kde.KSplash /KSplash org.kde.KSplash setStage s ksmserver
t=$(date +%s); setsid -f nix develop --command qs -p ./MacShell >/dev/null 2>&1
wait $pid; echo "splash closed after $(( $(date +%s) - t )) s"
```

**Expected:** a few seconds (MacShell's start-up plus the picture loading). Without this branch the same block prints about 30 s; to see that, run it once with the `setsid` line removed.

Then check that a stray call doesn't start anything. With MacShell running and no splash up, run `pgrep -a plasma_waitforname`. **Expected:** no output, because `--auto-start=no` stops D-Bus activation.

Finish with the rollback steps above. For a real login without `plasmashell`, see [`12-replace-default-tests.md`](12-replace-default-tests.md).

## 3. Regressions (with `plasmashell` running)

- The wallpaper picker still sets Plasma's wallpaper (`[wallpaper] applied with: plasma-apply-wallpaperimage`), and the glass follows it.
- No QML warnings appear about `Wallpaper.qml`, `desktopUnserved` or `sessionKnown`. The known missing `~/.face` warning can be ignored.
- No KSplash call is made while `plasmashell` runs.

## Results

| Check | Result (`pass` / `fail` / `partial`) | Evidence |
| --- | --- | --- |
| 1. Wallpaper appears without `plasmashell` | | |
| 1. Picker, sharpness, multi-screen, Overview / Show Desktop, glass | | |
| 1. `plasmashell` coming back removes MacShell's wallpaper | | |
| 2. Splash closes in seconds, not 30 s | | |
| 2. No `plasma_waitforname` started | | |
| 3. Regressions | | |

Change `wip` commits to `feat`/`fix` only after their row passes (AGENTS.md §12).
