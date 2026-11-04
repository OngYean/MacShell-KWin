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
  <a href="#running-it-next-to-plasma">Running it</a> ·
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
screen, PowerDevil, portals, Polkit agent, KIO, network and Bluetooth services keep doing their jobs. MacShell can run
**next to** `plasmashell` or, for one login, **in its place**. Nothing it does is permanent: logging out and back in
always gives you normal Plasma.

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
- **Coexistence with Plasma.** MacShell checks which KDE services already own notifications, the tray watcher and
  the menu view, and never starts a duplicate. `macshell-session` switches a single login between Plasma's shell and
  MacShell (`replace` / `restore`) without changing any configuration.
- **Notifications without a Plasma system tray.** If no Plasma tray serves notifications for 15 seconds, MacShell
  does.
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
| Wallpaper | Set with `awww` / `swww` / `hyprpaper` | Plasma's wallpaper: the glass follows it, and the picker sets it |
| Blur behind the bar | Hyprland layer rules | KWin's blur, requested for the bar strip only |
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
- **Blur behind the Dock and popovers.** Not implemented for KWin yet.
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
| `autostart` | `false` | Starts `macshell.service` with every Plasma session (and only Plasma sessions). `plasmashell` keeps running. |
| `package` | this flake's `macshell` | The package to use. |

The module never disables `plasmashell` or any KDE service. It works the same with standalone Home Manager.

To **update**, run `nix flake update macshell` and rebuild. MacShell's Settings tells you when this fork has a
newer version, but never installs anything itself.

### Try it without installing (Nix)

```sh
nix run github:OngYean/MacShell-KWin#macshell        # Ctrl+C stops it
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
   make it executable, and add it in System Settings → Autostart → Add… → Add Login Script.

Without Nix there is no `macshell` / `macshell-session` command. Use `qs -p /path/to/MacShell` in their place, and
see [Running it](#running-it-next-to-plasma) for the manual replace / restore steps.

## Running it next to Plasma

```sh
macshell                       # start MacShell in the foreground (Ctrl+C or `macshell kill` stops it)
macshell-session status        # what is running: plasmashell, MacShell, and a summary from the KWin bridge
macshell-session start | stop  # start or stop MacShell next to plasmashell
macshell-session replace       # for this login only: stop plasmashell, MacShell takes over notifications
macshell-session restore       # bring plasmashell back
```

- **Coexist** (the default): `plasmashell` keeps its panels, desktop, OSDs, clipboard history and, if it has a
  system tray, notifications. **Remove, move or auto-hide Plasma's top and bottom panels**, or they overlap
  MacShell's bar and Dock. MacShell's desktop icons duplicate Plasma's desktop folder view, so turn one of them off.
- **Replace** (`macshell-session replace`): Plasma's shell is stopped for the current login. Plasma's volume and
  brightness pop-ups, Klipper's clipboard history and Plasma's desktop are gone until `restore` or the next login.
  Without Nix: `systemctl --user stop plasma-plasmashell.service`, then `MACSHELL_KDE_MODE=replace qs -p ./MacShell`.
  Undo it with `systemctl --user start plasma-plasmashell.service`.

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
| The whole screen is blurred | A force-blur KWin effect (e.g. Better Blur) with "Blur docks" enabled. Turn that option off: MacShell asks KWin for blur where it needs it. |
| Brightness slider does nothing | `busctl --user status org.kde.ScreenBrightness` must show PowerDevil. |
| The glass shows another picture than the desktop | MacShell reads Plasma's wallpaper from `~/.config/plasma-org.kde.plasma.desktop-appletsrc`; with different wallpapers per screen only the first is used. |
| Bar and Dock overlap Plasma's panels | See [Running it](#running-it-next-to-plasma). |
| Logs | `macshell log` (or `qs log -p /path/to/MacShell`). |

## Known issues

- **Unverified fixes:** the latest fixes for the bar background, force-blur effects, brightness, notifications
  without a tray, wallpaper sync and menu icons haven't been run in a live Plasma session yet
  (`handoff/08-plasma-fixes-tests.md` is the test plan).
- **Global menu:** no keyboard navigation; submenus open inside the same popover rather than cascading; menus of
  GTK apps, Electron apps, Firefox, VS Code and Xwayland apps are untested. Mnemonics are stripped, not underlined.
- **No live window previews**, and the glass refracts only the wallpaper (KWin offers no window capture to
  clients).
- The Settings, About and Clock windows draw their own frame, so they don't get your KWin decoration.
- KWin's per-screen virtual desktops (off by default) aren't reflected: every screen shows the current desktop.
- A Plasma system tray added *after* MacShell has taken over notifications in the same login gets none until
  MacShell is stopped and `plasmashell` restarted.

To get your normal desktop back at any point: `Ctrl+C` (or `macshell kill`), `macshell-session restore` if you used
`replace`, and in the worst case log out and back in. To uninstall, set `programs.macshell.enable = false` (or
remove the module) and rebuild. MacShell's settings stay in the folders listed above.

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

Apple, the Apple logo and macOS are trademarks of Apple Inc. This project is not affiliated with or endorsed by
Apple.
