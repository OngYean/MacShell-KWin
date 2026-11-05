<h1 align="center">MacShell for KDE Plasma</h1>

<p align="center">
  <img width="128" height="128" alt="MacShell logo" src="MacShell/assets/macshell-logo.png" />
</p>

<p align="center">
  A macOS Tahoe–style <b>menu bar, Dock and desktop</b> for <b>KDE Plasma 6 on Wayland (KWin)</b>,
  built on <a href="https://quickshell.org">Quickshell</a>.<br>
  A fork of <a href="https://github.com/0-ss/MacShell"><b>MacShell</b></a> by Rickky, ported from Hyprland to KWin.
</p>

<p align="center">
  <a href="#changes-compared-to-the-original-macshell">Changes</a> ·
  <a href="#requirements">Requirements</a> ·
  <a href="#install">Install</a> ·
  <a href="#running-it">Running it</a> ·
  <a href="#troubleshooting">Troubleshooting</a> ·
  <a href="#known-issues">Known issues</a> ·
  <a href="#credits-and-licence">Credits</a>
</p>

> [!IMPORTANT]
> **On Hyprland? Use the original project: [0-ss/MacShell](https://github.com/0-ss/MacShell).** It has the Hyprland
> installer, keybinds and layer rules, live window previews and the MacLock lock screen. This fork still contains
> the Hyprland code path, but it doesn't document, test or support it.

> [!WARNING]
> **Experimental.** MacShell runs in a Plasma 6.8 Wayland session, and real application menus show in its menu bar.
> Several recent fixes haven't been verified in a live session yet (see [Known issues](#known-issues)). Keep
> Plasma's own panels available as a fallback while you try it.

MacShell replaces only what you *see* of Plasma: the top bar, the Dock, Spotlight, Control Center, notifications,
desktop widgets and the wallpaper picker. Everything underneath stays KDE: **KWin** remains the compositor (with its
effects and your window decorations, e.g. Breeze or [Klassy](https://github.com/paulmcauley/klassy)), and KDE's lock
screen, PowerDevil, portals, Polkit agent, KIO, network and Bluetooth services keep doing their jobs. By default
MacShell runs **in place of** `plasmashell`; it can also run **next to** it. `plasmashell` is never uninstalled or
masked: `macshell-session coexist` brings it back for the current login, and the Home Manager settings below decide
what each login starts.

The look is the same as the original's; see [its screenshots](https://github.com/0-ss/MacShell#screenshots).

## Changes compared to the original MacShell

Compared with [0-ss/MacShell](https://github.com/0-ss/MacShell) at commit
[`51db0ba`](https://github.com/0-ss/MacShell/commit/51db0bab6997da310d2aacfaa7084740ec44ad4a) (version 0.5.1,
2026-11-02), the point this fork started from.

### Added

- **KDE Plasma (KWin) support.** A compositor layer (`MacShell/backends/compositor/`) chooses Hyprland or KWin when
  the shell starts (set `MACSHELL_COMPOSITOR=kwin|hyprland|none` to force one), so the interface no longer calls
  Hyprland directly.
- **`macshell-kwin-bridge`** (`kwin-bridge/`), a small helper program that gives MacShell KWin's window list, the
  active window, virtual desktops, keyboard layouts and the active application's menu.
- **A real global menu.** The menu bar shows the active app's own menus, the ones KDE's Global Menu widget shows,
  with submenus, separators, disabled and checkable items, shortcut labels and icons. MacShell registers itself as a
  menu view, so apps export their menus even without Plasma's Global Menu widget.
- **Replacing Plasma's shell, or running next to it.** `macshell-session start` runs MacShell in place of
  `plasmashell` (the default); `macshell-session coexist` runs it next to `plasmashell`. Either switches the current
  login without changing any configuration. With Home Manager autostart, `plasmashell` is skipped at login and
  started again if MacShell keeps failing. MacShell checks which KDE services already own notifications, the tray
  watcher and the menu view, and never starts a duplicate. Logging in without `plasmashell` hasn't been tested yet.
- **Notifications without a Plasma system tray.** If no Plasma tray serves notifications for 15 seconds, MacShell
  does.
- **Wallpaper and login splash without `plasmashell`.** In replace mode MacShell draws the wallpaper itself (your
  last pick in its picker, otherwise the picture Plasma is set to) and tells Plasma's login splash screen that the
  desktop is ready, which `plasmashell` normally does. Not yet tested in Plasma.
- **Use KWin's blur** (Settings → Appearance). Every glass surface becomes a see-through tint and KWin blurs what's
  behind it, instead of MacShell's own Liquid Glass. See [KWin's blur](#kwins-blur). Not yet tested in Plasma.
- **Nix flake**: the packages `macshell`, `macshell-kwin-bridge` and `macshell-hyprland`, a Home Manager module
  (`programs.macshell`, with optional autostart) and a development shell.
- **Tests**: a fake bridge for trying the interface without KWin, a smoke test against a headless KWin, shell-script
  tests and GitHub Actions CI.

### Changed (on KDE Plasma)

| Feature | Original (Hyprland) | This fork on KDE Plasma |
| --- | --- | --- |
| Window list, Dock, app switcher, active app name | Hyprland IPC and Quickshell's toplevel list | KWin, through the bridge |
| Workspaces | Hyprland workspaces | KWin virtual desktops |
| Keyboard layout indicator | `hyprctl` | KWin's keyboard layouts |
| Lock | MacLock | KDE's screen locker |
| Log Out, Restart, Shut Down | `uwsm` / `hyprctl` / `systemctl` | KDE's session manager (your session is saved) |
| Screenshots and screen recording | `grim`, `slurp`, `wf-recorder` | Spectacle |
| Display, keyboard, mouse, trackpad and Night Shift settings | `hyprctl`, `hyprsunset` | Open the matching page of KDE System Settings |
| Screen brightness | `brightnessctl` / `ddcutil` | PowerDevil (also controls DDC monitors) |
| Wallpaper | Set with `awww` / `swww` / `hyprpaper` | While `plasmashell` runs, Plasma's wallpaper: the glass follows it, and the picker sets it. Without `plasmashell`, MacShell draws the picker's choice itself |
| Blur behind the bar | Hyprland layer rules | KWin's blur, requested for the bar strip only; with "Use KWin's blur", for every glass surface |
| Liquid Glass refraction | Live windows and the wallpaper | The wallpaper only |
| Shortcut items in the generic File/Edit menus | `hyprctl sendshortcut` / `wtype` | `ydotool`, if installed |
| Game Mode | Also tunes Hyprland, the power profile and the video wallpaper | Quiets MacShell's own effects only |
| Settings → Software Update | Checks 0-ss/MacShell | Checks this fork (OngYean/MacShell-KWin); it only notifies, you update with Nix or git |

### Removed or unavailable on KDE Plasma

No upstream code has been deleted; the Hyprland path is kept, but untested. On KDE Plasma you don't get:

- **Live window previews** in the Dock or in the glass, and dragging a window copy out of the Dock. KWin doesn't let
  ordinary programs capture windows, so the Dock shows app icons instead.
- **Colour picker** (`hyprpicker`).
- **Window layout controls** in the window menu (float, pin, split, move and resize). KWin's own window menu has
  these.
- **MacLock.** KDE's lock screen is used instead.
- **`install.sh`, the graphical installer and the self-updater.** These are Hyprland-only; install and update with
  Nix or git (see [Install](#install)).
- **Hyprland keybinds and layer rules.** Bind keys in KDE's Shortcuts settings instead
  ([below](#keyboard-shortcuts)).
- **Blur behind the Dock and popovers in the Normal Blur style**, unless "Use KWin's blur" is on. Without it they're
  a plain tint on KWin.
- **A window list on other wlroots compositors** (Sway, niri, river). They now get no compositor backend.
- **MacShell's notification list while Plasma's tray serves notifications.** They appear in Plasma instead.

## Requirements

| What | Notes |
| --- | --- |
| **KDE Plasma 6, Wayland session** | Developed against Plasma and KWin 6.8.2 with Qt 6.12. X11 sessions aren't supported. |
| **Quickshell 0.3.x** | With QtMultimedia available to QML. The Nix package provides both. |
| **`macshell-kwin-bridge`** | Built from `kwin-bridge/` (Qt 6, KWayland). The Nix package provides it. |
| KDE components Plasma already ships | kded's AppMenu module (global menu), PowerDevil (brightness), KDE's screen locker, Spectacle (screenshots), System Settings, `plasma-apply-wallpaperimage`, `dbus-send` |
| An icon theme for Qt apps | App icons in the Dock and Spotlight come from the system icon theme. |
| Optional | NetworkManager (`nmcli`) for Wi-Fi; `bluez` (`bluetoothctl`) for Bluetooth; `wl-clipboard` and `cliphist` for clipboard history; `wpctl` or `pactl` for audio devices; `zenity` or `kdialog` for file pickers; `fastfetch` for "About This Linux"; `ydotool` for shortcut items in the generic menus. Missing tools disable only their feature. |

Optional: [Klassy](https://github.com/paulmcauley/klassy) gives KWin macOS-like window decorations (rounded
corners and traffic-light buttons). Install it from your distribution and pick it in System Settings → Colors &
Themes → Window Decorations. MacShell never draws decorations itself.

## Install

> [!CAUTION]
> Don't run `install.sh` or the graphical installer on KDE Plasma. They are the original project's Hyprland
> installers: they install Hyprland packages and edit Hyprland's configuration.

### NixOS with Home Manager (recommended)

This is the route the port is developed and tested with. Enable Plasma 6 in your system configuration
(`services.desktopManager.plasma6.enable = true;`), then add this repository to your **system flake** and pass
`inputs` to Home Manager. Replace `your-user` and `your-host` with your own names:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    macshell = {
      url = "github:OngYean/MacShell-KWin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.users.your-user = { inputs, ... }: {
            imports = [ inputs.macshell.homeManagerModules.macshell ];
            programs.macshell = {
              enable = true;
              autostart = false;   # true: start MacShell with every Plasma session
            };
          };
        }
      ];
    };
  };
}
```

Run `nix flake lock`, then rebuild your system as usual (for example `sudo nixos-rebuild switch --flake .#your-host`).

| `programs.macshell` option | Default | Effect |
| --- | --- | --- |
| `enable` | `false` | Installs `macshell` and `macshell-session`, and defines the `macshell.service` user unit. |
| `autostart` | `false` | Starts `macshell.service` with every Plasma session (and only Plasma sessions). |
| `mode` | `"replace"` | With `autostart`: `"replace"` skips `plasmashell` at login and MacShell takes its place; `"coexist"` starts `plasmashell` as usual and MacShell next to it. |
| `package` | this flake's `macshell` | The package to use. |

In `"replace"` mode the module doesn't disable, mask or remove `plasmashell`. It adds a condition to Plasma's
`plasma-plasmashell.service` (a drop-in, `ConditionEnvironment=!MACSHELL_KDE_MODE=replace`) and sets
`MACSHELL_KDE_MODE=replace` for your user's services. If MacShell fails three times within a minute,
`macshell-fallback.service` starts `plasmashell` instead. `macshell-session coexist` brings `plasmashell` back for the
current login. `mode = "coexist"` or `autostart = false` brings it back at every login after you rebuild, log out
and log in again. No other KDE service is touched. It works the same with standalone Home Manager.

To **update**, run `nix flake update macshell` and rebuild. MacShell's Settings tells you when this fork has a
newer version, but never installs anything itself.

### Try it without installing (Nix)

```sh
nix run github:OngYean/MacShell-KWin#macshell-session -- start     # in place of plasmashell, for this login
nix run github:OngYean/MacShell-KWin#macshell-session -- stop      # stop MacShell, plasmashell comes back
nix run github:OngYean/MacShell-KWin#macshell                      # next to plasmashell, in the foreground; Ctrl+C stops it
```

This works on any distribution with Nix and flakes enabled. Use `#macshell`: the flake's default app is the
Hyprland build. On distributions other than NixOS, Nix-built graphical programs sometimes can't find your GPU
drivers ([nixGL](https://github.com/nix-community/nixGL) fixes that); this route is untested there.
`nix profile install github:OngYean/MacShell-KWin#macshell` installs it permanently.

### Other distributions, without Nix (untested)

There is no distribution package yet. You can run MacShell straight from a clone:

1. Install Quickshell 0.3.x, Qt 6 (base, declarative, wayland, multimedia, svg), and the development files for Qt 6,
   KWayland and the Wayland client library, plus CMake, pkg-config and a C++20 compiler. Package names differ
   between distributions.
2. Build the bridge, install it into `~/.local/bin` (which must be on your `PATH`), and start the shell:

   ```sh
   git clone https://github.com/OngYean/MacShell-KWin
   cd MacShell-KWin
   cmake -S kwin-bridge -B build -DCMAKE_BUILD_TYPE=Release
   cmake --build build
   cmake --install build --prefix ~/.local
   qs -p ./MacShell                     # Ctrl+C stops it
   ```

3. To start it at login, save a two-line script (`#!/bin/sh` and `exec qs -p /path/to/MacShell-KWin/MacShell`),
   make it executable, and add it in System Settings → Autostart → Add… → Add Login Script. This runs it next to
   `plasmashell`; see [Running it](#running-it) for replacing it.

Without Nix there is no `macshell` / `macshell-session` command. Use `qs -p /path/to/MacShell` in their place, and
see [Running it](#running-it) for the manual steps.

## Running it

```sh
macshell-session start         # in place of plasmashell, for this login (the default; `replace` is the same)
macshell-session coexist       # next to plasmashell, starting it again if needed (`restore` is the same)
macshell-session stop          # stop MacShell; plasmashell comes back
macshell-session status        # what is running: plasmashell, MacShell, and a summary from the KWin bridge
macshell                       # MacShell in the foreground, next to whatever runs (Ctrl+C or `macshell kill` stops it)
```

- **Replace** (the default: `macshell-session start`, or Home Manager `autostart` with `mode = "replace"`): Plasma's
  shell doesn't run. MacShell draws the wallpaper, takes over notifications and ends Plasma's login splash screen.
  Plasma's volume and brightness pop-ups, Klipper's clipboard history and Plasma's desktop (its icons and widgets)
  are gone until `macshell-session coexist` or `stop`.
  Without Nix: `systemctl --user stop plasma-plasmashell.service`, then `MACSHELL_KDE_MODE=replace qs -p ./MacShell`.
  Undo it with `Ctrl+C`, then `systemctl --user start plasma-plasmashell.service`.
- **Coexist** (`macshell-session coexist`, or `mode = "coexist"`): `plasmashell` keeps its panels, desktop, pop-ups,
  clipboard history and, if it has a system tray, notifications. **Remove, move or auto-hide Plasma's top and bottom
  panels**, or they overlap MacShell's bar and Dock. MacShell's desktop takes the clicks meant for Plasma's desktop
  icons, so remove Plasma's or turn MacShell's off.

**Global menu:** Qt and GTK apps check once, at start, whether a global menu is available. Apps that were already
running before MacShell keep their own menu bar until you restart them.

### Keyboard shortcuts

Bind MacShell's actions in System Settings → Keyboard → Shortcuts → Add New → Command or Script, for example
`Meta+Space` → `macshell ipc call spotlight toggle`. Without Nix, use `qs -p /path/to/MacShell ipc call …`.
KWin's own task switcher stays on Alt+Tab.

| Target | Functions |
| --- | --- |
| `spotlight` | `toggle`, `clipboard`, `emoji`, `apps` |
| `screenshot` | `region`, `screen`, `window` (Spectacle on KDE) |
| `wallpapers` | `toggle`, `open`, `close` |
| `switcher` | `next`, `prev`, `commit`, `cancel` |
| `settings` | `open` |
| `widgets` | `refresh` (re-fetch the weather), `edit true\|false` |

### KWin's blur

By default MacShell draws its glass itself. Liquid Glass blurs and bends a picture of the wallpaper, and the Normal
Blur style is a plain tint on KWin, so the windows behind a menu or the Dock don't show through. Turn on
**Settings → Appearance → Use KWin's blur** (shown on KWin only) to hand the blur to KWin instead:

- These become a see-through tint:
  - the bar strip (when "Liquid Glass bar" is on);
  - menus and popovers, notification banners, the Control Center and Spotlight;
  - the window switcher, the wallpaper picker and the volume/brightness pop-up;
  - the Dock, its labels and its right-click menu;
  - the desktop's right-click menu and its Rename, Quick Preview and Add Folder sheets;
  - Liquid Glass desktop widgets.
- MacShell asks KWin to blur what's behind each of them, cut to its rounded corners, the same way KDE's own apps ask
  for blur (the `ext-background-effect` Wayland protocol).
- The strength of the blur is KWin's: System Settings → Desktop Effects → Blur must be enabled. A replacement blur
  effect such as Better Blur should work too if it honours what apps request. Keep its force-blur of docks off for
  MacShell, or it blurs the whole screen (see [Troubleshooting](#troubleshooting)).
- **Translucency** (Appearance) still sets how strong the tint is. The Liquid Glass sliders, Menu Bar style and Dock
  style don't apply while the option is on.
- MacShell's own glass rendering (wallpaper capture, blur passes, refraction shaders) is switched off.

Not affected: the Settings window's frosted scroll edge and the Clock app's tab marker, which blur MacShell's own
content rather than what's behind the window; the small pointer under Dock labels; and photo or solid-style widgets.
The option is stored as `kwinBlur` in `~/.config/macdock/settings.json`.

### Where settings are stored

| Path | Content |
| --- | --- |
| `~/.config/macbar/settings.json` | Menu bar settings |
| `~/.config/macdock/settings.json`, `pinned.json` | Dock settings and pinned apps |
| `~/.config/macwidgets/settings.json`, `images/` | Desktop widgets and the pictures of Image widgets |
| `~/.cache/macbar/` | Clipboard history helper files |
| `~/Pictures/Screenshots` | Default screenshot folder |

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Empty Dock, generic File/Edit/View menus everywhere | Is the bridge running? `nix run github:OngYean/MacShell-KWin#kwin-bridge -- --check` (or `macshell-kwin-bridge --check`) prints a summary with counts only. |
| One app still shows its own menu bar | It started before MacShell: restart it. `busctl --user status com.canonical.AppMenu.Registrar` must succeed while MacShell runs. |
| No notifications | `busctl --user status org.freedesktop.Notifications` shows who owns them. MacShell takes them only when nobody else has for 15 s. |
| No bar, Dock or wallpaper after login | MacShell didn't start and `plasmashell` was skipped. Open KRunner (`Alt+Space`) or a terminal and run `macshell-session stop` to get Plasma's shell; `journalctl --user -u macshell -b` shows why. |
| The whole screen is blurred | A force-blur KWin effect (e.g. Better Blur) with "Blur docks" enabled. Turn that option off: MacShell asks KWin for blur where it needs it. |
| Brightness slider does nothing | `busctl --user status org.kde.ScreenBrightness` must show PowerDevil. |
| The glass shows another picture than the desktop | MacShell reads Plasma's wallpaper from `~/.config/plasma-org.kde.plasma.desktop-appletsrc`; with different wallpapers per screen only the first is used. |
| Bar and Dock overlap Plasma's panels | See [Running it](#running-it-next-to-plasma). |
| Logs | `macshell log` (or `qs log -p /path/to/MacShell`). |

## Known issues

- **Unverified fixes:** the latest fixes for the bar background, force-blur effects, brightness, notifications
  without a tray, wallpaper sync and menu icons haven't been run in a live Plasma session yet
  (`handoff/08-plasma-fixes-tests.md` is the test plan). Neither has the wallpaper and splash handling without
  `plasmashell` (`handoff/10-replace-wallpaper-splash-tests.md`), nor "Use KWin's blur"
  (`handoff/11-kwin-blur-tests.md`).
- **Without `plasmashell`:** if Plasma's settings name no wallpaper picture (for example, you never changed Plasma's
  default wallpaper) and you haven't picked one in MacShell, the background stays black until you pick one. If you
  changed the wallpaper in Plasma after your last pick in MacShell, MacShell shows its own pick. Video wallpapers
  still go through `mpvpaper` there, which is untested on KWin.
- **Global menu:** no keyboard navigation; submenus open inside the same popover rather than cascading; menus of
  GTK apps, Electron apps, Firefox, VS Code and Xwayland apps are untested. Mnemonics are stripped, not underlined.
- **No live window previews**, and the glass refracts only the wallpaper (KWin offers no window capture to
  clients).
- The Settings, About and Clock windows draw their own frame, so they don't get your KWin decoration.
- KWin's per-screen virtual desktops (off by default) aren't reflected: every screen shows the current desktop.
- A Plasma system tray added *after* MacShell has taken over notifications in the same login gets none until
  MacShell is stopped and `plasmashell` restarted.

To get your normal desktop back at any point, run `macshell-session stop`, from KRunner (`Alt+Space`) or a terminal.
Without Nix, run `systemctl --user start plasma-plasmashell.service` after stopping MacShell. With Home Manager
autostart in replace mode, the next login starts MacShell again: set `mode = "coexist"` or `autostart = false` and
rebuild to get Plasma's shell at login. To uninstall, set `programs.macshell.enable = false` (or remove the module)
and rebuild. MacShell's settings stay in the folders listed above.

## Development

- `nix develop --command qs -p ./MacShell` runs the shell from the working tree with the bridge on `PATH`.
- `MACSHELL_KWIN_BRIDGE="$PWD/kwin-bridge/fake-bridge.py"` swaps in a fake bridge with made-up windows and menus,
  for testing the interface without KWin.
- `sh nix/test-macshell-session.sh`, `sh nix/test-brightness.sh` and `nix/kwin-smoke.sh` are the tests CI runs.
- `kwin-bridge/README.md` documents the bridge's protocol and why it uses the interfaces it does. `handoff/` holds
  the porting notes and test plans, and `AGENTS.md` the rules for contributors and coding agents.

## Credits and licence

- **MacShell** was created by [Rickky](https://github.com/0-ss) (owner), with [vSuol](https://github.com/vsoultann)
  (collaborator): [github.com/0-ss/MacShell](https://github.com/0-ss/MacShell). Almost everything you see comes
  from their work.
- **KDE Plasma / KWin port** by [OngYean](https://github.com/OngYean).
- **Open Runde** font by [Laurids Kern](https://github.com/lauridskern/open-runde), SIL Open Font License 1.1 (see
  `OFL.txt` next to each copy of the font).
- **Emoji data** from [GitHub gemoji](https://github.com/github/gemoji), MIT (notice in `MacShell/EmojiData.js`).
- Built on [Quickshell](https://quickshell.org), Qt and KDE Frameworks, and on KDE Plasma's KWin, PowerDevil and
  AppMenu infrastructure.

MacShell and this port are released under the [MIT licence](LICENSE).

Apple, the Apple logo and macOS are trademarks of Apple Inc. This project is not affiliated with, endorsed by or
sponsored by Apple Inc. The optional menu bar Apple logo (`MacShell/apple-logo-*.svg`) belongs to its rightful
copyright owner, Apple Inc., and is not covered by this project's MIT licence.
