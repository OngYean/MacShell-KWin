# Test plan: branch `kwin-plasma-fixes`

`AGENTS.md` remains the authority, and [`06-kwin-testing-guide.md`](06-kwin-testing-guide.md) still has the general runbook, ground rules and rollback. This file covers only the six bugs the user reported on 2026-11-04 in their Plasma 6.8.2 Wayland session, after the AppMenu export problem was fixed. The fixes were written on macOS without Nix, Quickshell or Plasma. Static checks and CI are listed under each fix. **None of the fixes has been run in Plasma.**

CI ([run 41752886675](https://github.com/OngYean/MacShell-KWin/actions/runs/41752886675), commit `9769c3c`) passed. The bridge compiles with the icon change. ShellCheck and `nix/test-brightness.sh` pass. The Home Manager module evaluates. Under a headless KWin 6.8.2, MacShell reaches "configuration loaded" with the real and the fake bridge, with only the known `~/.face` QML warning. The real bridge's messages still match the protocol. CI has no Plasma, PowerDevil, AppMenu registrar or force-blur effect, so it can't exercise any of the six behaviours.

## Setup

```sh
git fetch && git switch kwin-plasma-fixes && git pull
nix build .#macshell-kwin-bridge .#macshell -L      # the bridge changed (menu icons): this is its first local build
macshell kill 2>/dev/null                           # stop an autostarted MacShell, if any
nix develop --command qs -p ./MacShell              # foreground; Ctrl+C stops it
```

Rollback: `Ctrl+C`, then `git switch main`. Nothing on this branch writes Plasma or KWin configuration. The exceptions are the wallpaper step, which changes Plasma's wallpaper exactly as Plasma's own dialog would, and the brightness step, which changes screen brightness.

Sharing results: the usual rule applies. Share exit codes, `--check` output, QML warning lines and the commands below. Don't share raw bridge output or window lists.

## 1. Bar items invisible when "Bar background" is above Hidden

Fix (`df4d56b`): on KWin the fill is no longer a separate `macbarbg` layer. That layer could stack above the bar, where KWin's blur smeared the bar's items. The fill is now drawn inside the bar window under the items, with KWin's blur behind that strip only.

1. Settings → Menu Bar → Bar background: try about 0.2, then Tinted (0.6), then Hidden.
2. Expected: at every value the menu titles, icons and clock stay sharp. Above Hidden, the strip is tinted and blurred, if KWin's Blur effect (or a replacement) is enabled. At Hidden, the soft feather shows instead.
3. Repeat with Settings → "Liquid Glass bar" on and off.
4. If items are still smeared, record which of the two settings were on and whether a force-blur effect is enabled (see 2).

## 2. Force-blur effect blurs the whole screen

Fix (`b842ec1`): KWin turns a layer surface's namespace into its window type. MacShell's names (`macbar`, …) made every surface a Normal application window. Better Blur DX and similar effects blur a matched window's whole frame, ignoring transparency and the input mask. On KWin every MacShell surface now uses the namespace `dock`. Better Blur DX never force-blurs docks while its "Blur docks" option is off (the default).

1. Keep the force-blur effect configured as it was when the bug appeared.
2. Expected: the screen is no longer blurred, with MacShell idle and with a menu, Control Center, Spotlight or the Dock open.
3. Keyboard focus must still work: Spotlight (`qs -p ./MacShell ipc call spotlight toggle`, then type), the window switcher, the Wi-Fi password field and the wallpaper picker (`Ctrl+Alt+W`).
4. Overview (`Meta+W`) should not show MacShell's bar or Dock as windows.
5. If the screen is still blurred, check whether the effect's "Blur docks" option is on (it then blurs MacShell again by design). Record the effect's name and version.
6. Expected gap: only the bar strip asks KWin for blur. The Dock and popovers have none on KWin yet.

## 3. Brightness control doesn't change the real brightness

Fix (`333b1b7`, test `1c07f9b`): in a KDE session `MacShell/assets/brightness.sh` now asks PowerDevil (`org.kde.ScreenBrightness`) instead of `brightnessctl`. On NixOS, `brightnessctl` wasn't in the wrapper's PATH at all. `sh nix/test-brightness.sh` checks the script with a stand-in `dbus-send`.

1. `busctl --user status org.kde.ScreenBrightness | head -3`: PowerDevil must own it.
2. `sh MacShell/assets/brightness.sh get`. Expected: `kde <percent>`. If it prints `bl …` or `none …`, record `echo "$XDG_CURRENT_DESKTOP"` and `command -v dbus-send`.
3. Move MacShell's brightness slider (Control Center). Expected: the panel changes, Plasma's own brightness setting follows, and Plasma shows no OSD for it.
4. Press the brightness keys. PowerDevil handles them; MacShell's slider should follow within about a second. Record whether both Plasma's OSD and MacShell's OSD appear. Volume keys already behave like that in coexist mode.
5. With an external DDC monitor attached, both displays should change.

## 4. No notifications without a Plasma system tray

Fix (`5296408`): plasmashell serves `org.freedesktop.Notifications` only from its system tray. In coexist mode MacShell now takes the name once it has stayed unowned for 15 s, never while another process owns it.

1. Before starting MacShell: `busctl --user status org.freedesktop.Notifications`. An error means nobody owns it, which was the bug.
2. Start MacShell, wait 20 s, then `notify-send "MacShell test" "hello"`. Expected: a MacShell banner, and the notification in MacShell's bell.
3. `busctl --user status org.freedesktop.Notifications | grep -E '^(PID|Comm)='` should name the Quickshell process.
4. Only if a Plasma system tray exists somewhere: MacShell must not take the name (step 3 names plasmashell).
5. Known limit: a Plasma tray added later in the same login gets no notifications while MacShell holds the name. Stop MacShell, run `systemctl --user restart plasma-plasmashell.service`, then start MacShell again.

## 5. MacShell's wallpaper doesn't follow Plasma's (x-ray glass looks wrong)

Fix (`073e405`): while plasmashell runs, the glass refracts Plasma's wallpaper (from `appletsrc`) rather than MacShell's saved pick. Wallpaper packages, such as Plasma's built-in wallpapers, resolve to their largest image. MacShell's picker now detects plasmashell over D-Bus: on NixOS the process is `.plasmashell-wrapped`, so `pgrep -x plasmashell` never matched and picks went to awww/swww instead of Plasma. At start, MacShell no longer re-applies its last pick over Plasma's.

Use the Liquid Glass style, so the glass refracts the wallpaper.

1. Change the wallpaper in Plasma (right-click the desktop → Desktop and Wallpaper) to an image file. Within about 5 s, the Control Center or a menu should refract the new image. Then try one of Plasma's built-in wallpapers.
2. Pick a wallpaper in MacShell's picker (`Ctrl+Alt+W`). Expected: the desktop changes, the glass matches, and the console shows `[wallpaper] applied with: plasma-apply-wallpaperimage`.
3. Restart MacShell: Plasma's current wallpaper must stay. MacShell must not revert it to its own earlier pick.
4. If you use light/dark wallpaper pairs, switching the appearance should change Plasma's wallpaper.
5. If the glass is wrong, record the output of `awk -F= '/\]\[Wallpaper\]\[org.kde.image\]\[General\]/{w=1;next} /^\[/{w=0} w&&/^Image=/' ~/.config/plasma-org.kde.plasma.desktop-appletsrc`.
6. Known limit: with different wallpapers per screen, only the first containment's wallpaper is read.

## 6. No icons in MacShell's global menu

Fix (`0d9ef40` QML, `82fc3bc` bridge): items now carry their icon. A theme name is resolved through the icon theme. Qt's `icon-data` PNG, sent for icons without a theme name, arrives as a `data:` URL, capped at 16 KiB per item and 1 MiB per menu. Checkable items keep their check mark instead of an icon, as in KDE's menus.

1. With MacShell running, start KWrite and open File and Edit in MacShell's bar. Expected: the same icons as Plasma's Global Menu widget shows (New, Open, Save, Undo, …).
2. Repeat with Dolphin. Disabled items should show dimmed icons; toggles (View menu) should show check marks only.
3. If no icons show, share QML warning lines that mention `Image` or `iconPath` (not menu labels).

## Regressions to rule out

- MacShell starts with no new QML warnings (`qs -p ./MacShell` console; ignore the known missing `~/.face`).
- The global menu still shows real menus, and clicking an item still works (the menu code changed).
- Hyprland, if a session is available: the layer namespaces, the `macbarbg` layer and the `brightnessctl` path are unchanged there.

## Results

| Bug | Result (`pass` / `fail` / `partial`) | Evidence |
| --- | --- | --- |
| 1. Bar background hides bar items | | |
| 2. Force blur blurs the screen | | |
| 3. Brightness | | |
| 4. Notifications without a tray | | |
| 5. Wallpaper sync / x-ray | | |
| 6. Global menu icons | | |
| Regressions | | |

Change `wip` commits to `feat`/`fix` only after their row passes (AGENTS.md §12).
