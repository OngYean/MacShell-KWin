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
- **KWin's blur, per panel** (Settings → Appearance → Panels). Each panel (Dock, menu bar, menus and popovers,
  Control Center, notifications, Spotlight, switcher and pop-ups, desktop, widgets) can be a see-through tint with
  KWin's blur behind it, or keep MacShell's own glass ("Stock blur"). See [KWin's blur](#kwins-blur). Seen working
  in Plasma with one switch for everything; the per-panel choice and the fixes that followed that test (blur out of
  place after an opening animation, the Dock's blur redrawn while hovered or when its right-click menu opens) are not
  yet tested.
- **Transparency per panel** (Settings → Appearance → Panels): a Clear-to-Solid slider for each of the same panels.
  The original has one translucency value for everything, and no control for it in Settings. Not yet tested.
- **Title without a window** (Settings → Menu Bar): the name the menu bar shows while no window is active, instead
  of "Desktop". Not yet tested.
- **Minimizing into the Dock.** KWin's Magic Lamp effect animates a minimized window into its Dock icon (or its own
  window cell) instead of towards the pointer. Restoring it comes out of the same place, whether you click the Dock,
  use Alt+Tab or a shortcut. Not yet tested in Plasma; a CI check against a headless KWin covers only that KWin
  receives the target, not the animation.
- **Minimized windows as pictures in the Dock** (Settings → Desktop & Dock → "Show window previews", on by
  default). On KDE a minimized window sits next to the Trash as a small picture of itself with its app's icon as a
  badge, as on macOS. KWin takes the picture once, when the window is minimized; nothing is captured live. Not yet
  tested in Plasma, and the bridge code for it has not been compiled yet.
- **Applications start as their own systemd units** on KDE (`app-macshell-<id>@….service` in `app.slice`), like
  Plasma's own launchers, so they are not children of MacShell and survive a restart of it. Falls back to a direct
  start. Not yet tested in Plasma.
- **Desktop-entry actions** (New Window, New Private Window, …) in the Dock icon's right-click menu, in Spotlight's
  results and on right-click in Spotlight's application grid. Not yet tested.
- **Submenus open to the side** (Settings → Menu Bar, off by default): a submenu of an application's menu opens
  next to its parent row instead of replacing the menu. Not yet tested in Plasma.
- **Follow KDE's accent color** (Settings → Appearance, on by default on KDE). MacShell uses the highlight colour
  Plasma paints with and follows changes made in System Settings → Colors; a colour picked in MacShell is applied
  to Plasma too. Not yet tested in Plasma.
- **KDE's text rendering** (Settings → Appearance, off by default). Text is drawn by the system's rasterizer and so
  follows KDE's font settings (anti-aliasing, hinting, sub-pixel). Needs a restart of MacShell, and is soft at UI
  scales other than 100 %. Not yet tested.
- **Screen corner radius** (Settings → Appearance, off by default): black rounded corners on every screen, like a
  MacBook's display. Not yet tested.
- **Scroll wheel on volume and brightness**: on the Control Center's Display and Sound tiles, on every Control
  Center style slider, and on a new optional "Display brightness" icon in the menu bar (Settings → Menu Bar). Not
  yet tested.
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
| Blur behind the bar | Hyprland layer rules | KWin's blur, requested for the bar strip only; for every panel set to "KWin blur" (Appearance → Panels) |
| "Show window previews" (Desktop & Dock) | Live previews of open windows | Still pictures of minimized windows. "Live window capture" is hidden: KWin offers none |
| Dock Size and Magnification sliders | Applied at every step of a drag | Applied at most every 150 ms during a drag: each step resizes the Dock's window, which froze the shell. Not yet tested |
| Liquid Glass refraction | Live windows and the wallpaper | The wallpaper only |
| Shortcut items in the generic File/Edit menus | `hyprctl sendshortcut` / `wtype` | `ydotool`, if installed |
| Game Mode | Also tunes Hyprland, the power profile and the video wallpaper | Quiets MacShell's own effects only |
| Settings → Software Update | Checks 0-ss/MacShell | Checks this fork (OngYean/MacShell-KWin); it only notifies, you update with Nix or git |
| Menu popovers | Always 260 px wide; long entries cut off with "…" | As wide as the longest entry needs (up to 640 px). Not yet tested |
| Dock icons | Loaded at exactly the Dock's icon size, again at every step of the Size slider | Loaded in 64 px steps, so dragging Size or Magnification no longer freezes the shell with SVG icon themes. Not yet tested |
| Terminal apps started from the Dock | Started without a terminal | Open in the configured terminal, as from Spotlight (also on Hyprland). Not yet tested |
| Desktop widgets | On the first screen only | On any screen (also on Hyprland): a new widget goes on the screen the Settings window is on, and in edit mode a widget can be dragged onto another screen. The widgets of an unplugged screen are kept and come back with it. Not yet tested |
| App name and menus in the menu bar | The active window's, the same on every screen | One per screen: each screen's bar shows the window that was last active on that screen. On a screen you aren't working on, the name is dimmed and shown without menus, and a click on it activates that window. A screen without such a window shows the desktop's name and menus. Hyprland keeps the shared title. Not yet tested |
| Menu bar and popover icons | Drawn at 100 % and stretched by the UI scale and bar height, so blurry at other sizes | Drawn at the size they're shown at, and again when the display scale changes; tray icons loaded at 64 px. Not yet tested in Plasma |

### Removed or unavailable on KDE Plasma

No upstream code has been deleted; the Hyprland path is kept, but untested. On KDE Plasma you don't get:

- **Live window previews** in the Dock or in the glass, and dragging a window copy out of the Dock. KWin has no
  capture protocol for ordinary programs. A minimized window gets a still picture instead (see Added); open
  windows show app icons.
- **Colour picker** (`hyprpicker`).
- **Window layout controls** in the window menu (float, pin, split, move and resize). KWin's own window menu has
  these.
- **MacLock.** KDE's lock screen is used instead.
- **`install.sh`, the graphical installer and the self-updater.** These are Hyprland-only; install and update with
  Nix or git (see [Install](#install)).
- **Hyprland keybinds and layer rules.** Bind keys in KDE's Shortcuts settings instead
  ([below](#keyboard-shortcuts)).
- **Blur behind the Dock and popovers in the Normal Blur style**, unless the panel is set to "KWin blur". Without
  it they're a plain tint on KWin.
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
Blur style is a plain tint on KWin, so the windows behind a menu or the Dock don't show through.
**Settings → Appearance → Panels** (the blur choice is shown on KWin only) lets each panel hand the blur to KWin
instead. You can mix them: for example "Stock blur" for the Dock and "KWin blur" for everything else.

- The panels:
  - Dock: the Dock, its labels and its right-click menu;
  - Menu bar: the bar strip (when "Liquid Glass bar" is on);
  - Menus and popovers: app menus, tray menus, calendar, keyboard layout, sound, Wi-Fi and Bluetooth;
  - Control Center;
  - Notifications: banners and the notification centre;
  - Spotlight;
  - Switcher and pop-ups: the window switcher, the wallpaper picker and the volume/brightness pop-up;
  - Desktop: the right-click menu and the Rename, Quick Preview and Add Folder sheets;
  - Widgets: Liquid Glass desktop widgets.
- A panel set to "KWin blur" becomes a see-through tint. MacShell asks KWin to blur what's behind it, cut to its
  rounded corners, the same way KDE's own apps ask for blur (the `ext-background-effect` Wayland protocol), and
  doesn't run its own glass rendering (wallpaper capture, blur passes, refraction shaders) for that panel.
- The slider next to each panel sets how strong its tint is, from Clear to Solid, with either blur.
- The strength, saturation and brightness of the blur are KWin's: System Settings → Desktop Effects → Blur must be
  enabled. A replacement blur effect such as Better Blur should work too if it honours what apps request. Keep its
  force-blur of docks off for MacShell, or it blurs the whole screen (see [Troubleshooting](#troubleshooting)).
- The Liquid Glass sliders, Menu Bar style and Dock style only apply to panels on "Stock blur".

Not affected: the Settings window's frosted scroll edge and the Clock app's tab marker, which blur MacShell's own
content rather than what's behind the window; the small pointer under Dock labels; and photo or solid-style widgets.

The choices are stored in `~/.config/macdock/settings.json` as `panelBlur` (panel → `true` for KWin's blur) and
`panelTint` (panel → 0 to 1). A panel that was never picked follows the older `kwinBlur` switch for everything and
the global `glassOpacity`.

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
| Panels on "KWin blur" look yellowish | MacShell paints only a grey or white tint there. KWin's blur raises the saturation of what it blurs (150 % by default), and Better Blur's brightness setting multiplies it; with Night Light on, everything behind the panel is already warm, so both push it towards yellow. Set the blur effect's saturation and brightness to 100 %, or compare with Night Light off. Not confirmed on a real session. |
| Brightness slider does nothing | `busctl --user status org.kde.ScreenBrightness` must show PowerDevil. |
| The glass shows another picture than the desktop | MacShell reads Plasma's wallpaper from `~/.config/plasma-org.kde.plasma.desktop-appletsrc`; with different wallpapers per screen only the first is used. |
| Bar and Dock overlap Plasma's panels | See [Running it](#running-it-next-to-plasma). |
| Logs | `macshell log` (or `qs log -p /path/to/MacShell`). |

## Known issues

- **Unverified fixes:** the latest fixes for the bar background, force-blur effects, brightness, notifications
  without a tray, wallpaper sync and menu icons haven't been run in a live Plasma session yet
  (`handoff/08-plasma-fixes-tests.md` is the test plan). Neither has the wallpaper and splash handling without
  `plasmashell` (`handoff/10-replace-wallpaper-splash-tests.md`), nor the per-panel blur and transparency
  (`handoff/16-blur-panels-report.md`), nor minimizing into the Dock (`handoff/13-magic-lamp-tests.md`), nor
  widgets on other screens and the per-screen title and menus (`handoff/17-per-screen-tests.md`).
- **Title and menus per screen:** a screen's bar only knows the windows that have been active since MacShell
  started, so a window you haven't clicked yet shows as the desktop on a screen you aren't working on. Only the
  active window's menus are loaded, so the other screens show a name without menus until you click it.
- **Minimizing into the Dock:** windows whose app has no Dock icon still fly towards the pointer. The target is
  where the icon rests, so the animation ignores magnification and ends where the Dock appears when it's hidden.
  When running next to `plasmashell`, a Plasma task manager registers its own targets, and KWin uses whichever
  panel is nearer the window.
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
