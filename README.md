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
  desktop is ready, which `plasmashell` normally does. The picture stays decoded in memory, so it is back immediately
  after unlocking instead of taking a few seconds. The unlock fix is not yet tested in Plasma.
- **KWin's blur, per panel** (Settings → Appearance → Panels). Each panel (Dock, Dock labels and menu, menu bar,
  menus and popovers, Control Center, notifications, Spotlight, switcher and pop-ups, desktop, widgets) can be a see-through tint with
  KWin's blur behind it, or keep MacShell's own glass ("Stock blur"). See [KWin's blur](#kwins-blur). Seen working
  in Plasma with one switch for everything; the per-panel choice and the fixes that followed that test (blur out of
  place after an opening animation, the Dock's blur redrawn while hovered or when its right-click menu opens) and the
  separate row for the Dock's labels and menu are not yet tested.
- **Transparency per panel** (Settings → Appearance → Panels): a Clear-to-Solid slider for each of the same panels.
  The original has one translucency value for everything, and no control for it in Settings. Not yet tested.
- **Title without a window** (Settings → Menu Bar): the name the menu bar shows while no window is active, instead
  of "Desktop". Not yet tested.
- **Minimizing into the Dock.** KWin's Magic Lamp effect animates a minimized window into its Dock icon (or its own
  window cell) instead of towards the pointer. Restoring it comes out of the same place, whether you click the Dock,
  use Alt+Tab or a shortcut. Seen working in Plasma on 2026-11-17, with one fault: a window restored from its own
  cell switched to its app's icon near the end of the animation. The Dock now leaves KWin's target alone for 1.2 s
  after a minimize or restore; that fix is not yet tested. As a result a window that is being minimized goes into
  its app's icon, and its own cell is the target from then on.
- **Minimized windows as pictures in the Dock** (Settings → Desktop & Dock → "Show window previews", on by
  default). On KDE a minimized window sits next to the Trash as a small picture of itself with its app's icon as a
  badge, as on macOS. KWin takes the picture once, when the window is minimized; nothing is captured live. Not yet
  tested in Plasma, and the bridge code for it has not been compiled yet.
- **Folders in the Dock.** Any folder can be pinned next to the Trash: Settings → Applications → Folders in Dock,
  or in Dolphin right-click a folder → Pin to MacShell Dock (a KDE service menu the Nix package installs; see
  [Keyboard shortcuts](#keyboard-shortcuts) for the command behind it). A click opens the folder as a stack above
  its icon, as macOS's fan: its newest items rise from the icon in a slight arc, each a name in a dark pill beside
  its icon (a picture shows itself), with "Open in File Manager" on top. A click on an item opens it; right-click
  the folder → Remove from Dock. Fan view only (no grid or list), and as many items as fit above the Dock: five at
  the default Dock size, the rest through "Open in File Manager". The fan, and a faster listing of the folder, are
  not yet tested in Plasma.
- **An Apple menu you can arrange** (Settings → Menu Bar → Apple Menu Items; also on Hyprland). Every item of the
  top-left menu, the existing ones included, can be moved up or down or removed, and separators and items of your
  own (a name and a shell command) can be added. A command typed next to a built-in item runs instead of what the
  item does, for example your own lock command for Lock Screen. Two items are new and in the default menu:
  - **Recent Items** lists the applications last started from the Dock or Spotlight and the most recent files.
    Applications started any other way (a terminal, KRunner) are not listed.
  - **Force Quit…** lists the open applications; a second click on one kills its processes.

  Both lists follow Settings → Menu Bar → "Submenus open to the side": off, they replace the menu under a "‹" row;
  on, they open in a panel beside their row, when the pointer rests on it or on a click.

  Not yet tested.
- **Click wallpaper to reveal desktop** (Settings → Desktop & Dock → Desktop, off by default, KDE only). A click
  on an empty part of the desktop turns on KWin's Peek at Desktop, which moves the windows aside; a second click
  brings them back, as does opening or activating a window. The menu bar, Dock, desktop icons and widgets stay.
  While `plasmashell` draws the desktop, MacShell only gets the click when Desktop Icons is on. Not yet tested in
  Plasma.
- **Applications start as their own systemd units** on KDE (`app-macshell-<id>@….service` in `app.slice`), like
  Plasma's own launchers, so they are not children of MacShell and survive a restart of it. Falls back to a direct
  start. Not yet tested in Plasma.
- **Desktop-entry actions** (New Window, New Private Window, …) in the Dock icon's right-click menu, in Spotlight's
  results and on right-click in Spotlight's application grid. Not yet tested.
- **A dot per open window under Dock icons** (Settings → Desktop & Dock → "Show a dot for each open window", on by
  default, shown while "Show indicators for open applications" is on). An app with several windows gets up to three
  dots instead of one; minimized windows and windows on other desktops count too. Off gives the single dot of the
  original. Not yet tested in Plasma.
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
- **MacLock as KDE's lock screen** (Home Manager `programs.macshell.lockScreen`, off by default): KDE's screen
  locker shows MacLock's screen (clock, Liquid Glass, Now Playing, lyrics, notifications) instead of its own. KDE
  still locks the session and checks the password; see [Lock screen](#lock-screen). Not yet tested.
- **Installing without Nix**: `install.sh` installs this port when it runs in a Plasma session (and removes it
  with `--uninstall`), `packaging/arch/PKGBUILD` builds an Arch package, and both use the CMake install rules in
  the top-level `CMakeLists.txt`. `macshell-session autostart replace|coexist|off` sets what a Plasma login starts
  for these installs. See [Install](#install). None of this has run on a real system yet.
- **Nix flake**: the packages `macshell`, `macshell-kwin-bridge`, `macshell-lock` and `macshell-hyprland`, a Home
  Manager module (`programs.macshell`, with optional autostart) and a development shell.
- **Optional programs are your choice in every way of installing** (kdialog for the folder pickers, cliphist for
  the clipboard history, and eight more): a switch per feature in the Home Manager module, described optional
  dependencies in the Arch package, and a question per feature in `install.sh`. See
  [Optional features](#optional-features). Not yet tested.
- **Tests**: a fake bridge for trying the interface without KWin, a smoke test against a headless KWin, shell-script
  tests and GitHub Actions CI.

### Changed (on KDE Plasma)

| Feature | Original (Hyprland) | This fork on KDE Plasma |
| --- | --- | --- |
| Window list, Dock, app switcher, active app name | Hyprland IPC and Quickshell's toplevel list | KWin, through the bridge |
| Workspaces | Hyprland workspaces | KWin virtual desktops |
| Keyboard layout indicator | `hyprctl` | KWin's keyboard layouts |
| Memory | Each glass backdrop, the desktop and the widgets decoded their own copy of the wallpaper; the bar's window was always 900 px taller than the bar; closed overlays kept their glass backdrop loaded | One decoded wallpaper per screen (also on Hyprland). On KDE the bar's window is short while nothing is open below it, and Spotlight, the app switcher, the wallpaper picker and the OSD load their backdrop when they open. Not yet tested or measured |
| Lock | MacLock locks the session and checks the password itself | KDE's screen locker does both; with `lockScreen` on, it shows MacLock's screen. Not yet tested in Plasma |
| Log Out, Restart, Shut Down | `uwsm` / `hyprctl` / `systemctl` | KDE's session manager (your session is saved) |
| Screenshots and screen recording | `grim`, `slurp`, `wf-recorder` | Spectacle |
| Display, keyboard, mouse, trackpad and Night Shift settings | `hyprctl`, `hyprsunset` | Open the matching page of KDE System Settings |
| Screen brightness | `brightnessctl` / `ddcutil` | PowerDevil (also controls DDC monitors) |
| Wallpaper | Set with `awww` / `swww` / `hyprpaper` | While `plasmashell` runs, Plasma's wallpaper: the glass follows it, and the picker sets it. Without `plasmashell`, MacShell draws the picker's choice itself |
| Blur behind the bar | Hyprland layer rules | KWin's blur, requested for the bar strip only; for every panel set to "KWin blur" (Appearance → Panels) |
| "Show window previews" (Desktop & Dock) | Live previews of open windows | Still pictures of minimized windows. "Live window capture" is hidden: KWin offers none |
| Dock Size and Magnification sliders | Applied at every step of a drag | Applied at most every 150 ms during a drag: each step resizes the Dock's window, which froze the shell. Not yet tested |
| Window positions and sizes | Hyprland events | Sent by the bridge at most 4 times a second, so windows that move or animate all the time (e.g. Proton game launchers) no longer make MacShell stutter. The Dock's smart-hide can react up to a quarter second later. Not yet tested |
| Liquid Glass refraction | Live windows and the wallpaper | The wallpaper only |
| Shortcut items in the generic File/Edit menus | `hyprctl sendshortcut` / `wtype` | `ydotool`, if installed |
| Game Mode | Also tunes Hyprland, the power profile and the video wallpaper | Quiets MacShell's own effects only |
| Settings → Software Update | Checks 0-ss/MacShell | Checks this fork (OngYean/MacShell-KWin); it only notifies, you update with Nix or git |
| Right-click menu of a Dock icon | Centred over its icon; the icons kept magnifying under the pointer while it was open, so the menu slid along with its icon | Hangs to the right of its icon with its pointer near its left end, as on macOS (also on Hyprland); near the screen's right edge it moves back. Hover labels stay centred. While it (or a folder's stack) is open the magnification holds still, wherever the pointer goes, so the menu stays put (also on Hyprland). Not yet tested |
| Battery icon in the menu bar | A grey outline, green while charging | White like the other items of the bar (also on Hyprland), with the charging bolt; red only at 15 % or less while not charging. Not yet tested |
| Menu popovers | Always 260 px wide; long entries cut off with "…" | As wide as the longest entry needs (up to 640 px). Not yet tested |
| Dock icons | Loaded at exactly the Dock's icon size, again at every step of the Size slider | Loaded in 64 px steps, so dragging Size or Magnification no longer freezes the shell with SVG icon themes. Not yet tested |
| Terminal apps started from the Dock | Started without a terminal | Open in the configured terminal, as from Spotlight (also on Hyprland). Not yet tested |
| Desktop widgets | On the first screen only | On any screen (also on Hyprland): a new widget goes on the screen the Settings window is on, and in edit mode a widget can be dragged onto another screen. The widgets of an unplugged screen are kept and come back with it. Not yet tested |
| App name and menus in the menu bar | The active window's, the same on every screen | One per screen: each screen's bar shows the window that was last active on that screen. On a screen you aren't working on, the name is dimmed and shown without menus, and a click on it activates that window. A screen without such a window shows the desktop's name and menus. Hyprland keeps the shared title. Not yet tested |
| Popovers and menus with several screens | Each screen's bar, Dock and desktop opens and closes its own | One at a time on all screens together (also on Hyprland): opening the Control Center, a bar menu or popover, Spotlight, the notification centre, a Dock icon's right-click menu or the desktop's right-click menu closes any of these that is open elsewhere, on that screen or another. A click on another screen closes it too: in the top part of that screen (the menu bar and about 900 px below it) the click is used up by closing, as it is beside a popover on its own screen; on a Dock icon or the empty desktop it closes and still does its own job. Not yet tested |
| `controlcenter` and `notifications` IPC | `controlcenter open` closed the Control Center when it was already open, like `toggle`; `notifications open` did the same, and `notifications` had no `toggle` | `open` only opens and `close` only closes (`controlcenter close` no longer closes another popover); `notifications toggle` is new (also on Hyprland). Not yet tested |
| Menu bar and popover icons | Drawn at 100 % and stretched by the UI scale and bar height, so blurry at other sizes | Drawn at the size they're shown at, and again when the display scale changes; tray icons loaded at 64 px. Not yet tested in Plasma |

### Removed or unavailable on KDE Plasma

No upstream code has been deleted; the Hyprland path is kept, but untested. On KDE Plasma you don't get:

- **Live window previews** in the Dock or in the glass, and dragging a window copy out of the Dock. KWin has no
  capture protocol for ordinary programs. A minimized window gets a still picture instead (see Added); open
  windows show app icons.
- **Colour picker** (`hyprpicker`).
- **Window layout controls** in the window menu (float, pin, split, move and resize). KWin's own window menu has
  these.
- **MacLock as the locker.** KDE's screen locker locks the session; MacLock can only be the screen it shows
  ([Lock screen](#lock-screen)). The Preview button in Settings → Lock Screen is hidden on KDE.
- **The graphical installer and the self-updater.** These are Hyprland-only. `install.sh` installs this port only
  in a Plasma session; update by pulling and installing again, or with Nix (see [Install](#install)).
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
| **`macshell-kwin-bridge`** | Built from `kwin-bridge/` (Qt 6, KWayland). The Nix package, the Arch package and `install.sh` provide it. |
| KDE components Plasma already ships | kded's AppMenu module (global menu), PowerDevil (brightness), KDE's screen locker, Spectacle (screenshots), System Settings, `plasma-apply-wallpaperimage`, `dbus-send` |
| An icon theme for Qt apps | App icons in the Dock and Spotlight come from the system icon theme. |
| Optional programs | See [Optional features](#optional-features). A missing program switches off only its own feature. |

### Optional features

Each feature below needs programs that MacShell looks for when it starts the feature and does without when they
are missing. Every way of installing lets you choose them one by one. Not yet tested on any of the three.

| Feature | Programs | Name |
| --- | --- | --- |
| Folder and file pickers: the Choose… buttons in Settings and picture widgets | `kdialog` (or `zenity`, `yad`) | `pickers` |
| Clipboard history in Spotlight | `cliphist`, `wl-clipboard` | `clipboardHistory` |
| The Trash icon changes at once instead of within 3 seconds | `inotify-tools` | `trashWatch` |
| File-type icons in a Dock folder's stack | `file` | `fileIcons` |
| The system report behind About This Linux | `fastfetch` | `systemReport` |
| Screenshots and screen recording | Spectacle | `screenshots` |
| Lyrics, stocks and location lookups in the widgets and on the lock screen | `curl`, `jq`, `python3` | `onlineLookups` |
| Colours taken from the wallpaper | ImageMagick | `wallpaperColors` |
| A small copy of a video wallpaper for the glass (much less memory) | `ffmpeg` | `videoGlass` |
| Shortcut items in the generic File and Edit menus | `ydotool` and its `ydotoold` service | `menuShortcuts` |

How to choose:

- **Home Manager:** `programs.macshell.features.<name> = true;` installs the feature's programs next to MacShell.
  All are off by default except `fileIcons`. Off installs nothing; a program that is on your `PATH` for another
  reason still works. `menuShortcuts` has no switch, because `ydotoold` is a system service
  (`programs.ydotool.enable` in NixOS). `nix run .#macshell` without the module uses whatever is on your `PATH`;
  the package itself no longer brings `file`.
- **Arch package:** they are the package's optional dependencies, each with what it gives
  (`pacman -Qi macshell-kwin-git`). Install the ones you want with `sudo pacman -S --asdeps <package>`.
- **`install.sh`:** after installing it asks about each feature whose programs are missing and installs the
  chosen ones with `pacman`, `dnf` or `apt-get` through `sudo` (Enter means no). `--features all`, `--features
  none` or `--features pickers,clipboardHistory` answers in advance, and `./install.sh --features-only` asks
  again later without rebuilding. Without a terminal and without `--features` nothing is installed.
- **By hand with CMake:** install the programs of the features you want yourself.

Screen brightness (PowerDevil), Wi-Fi (NetworkManager), Bluetooth (BlueZ) and the power mode
(power-profiles-daemon) depend on services your distribution sets up; the Arch package lists them as optional
dependencies too. Audio device switching uses `wpctl` (WirePlumber) or `pactl`.

Optional: [Klassy](https://github.com/paulmcauley/klassy) gives KWin macOS-like window decorations (rounded
corners and traffic-light buttons). Install it from your distribution and pick it in System Settings → Colors &
Themes → Window Decorations. MacShell never draws decorations itself.

## Install

| Method | For | State |
| --- | --- | --- |
| [Nix with Home Manager](#nixos-with-home-manager-recommended) | NixOS, or any system with Nix | The route the port is developed and tested with |
| [Arch package](#arch-linux-pkgbuild) | Arch Linux and derivatives | Untested |
| [`install.sh`](#any-distribution-installsh) | Any distribution, into `~/.local` or another prefix | Untested |
| [CMake by hand](#by-hand-with-cmake) | Packagers, or a system-wide install | Untested |
| [From a clone](#from-a-clone-without-installing) | Trying it or developing | Untested |

> [!CAUTION]
> `install.sh` does two different things. In a KDE Plasma session (or with `--kde`) it installs this port from your
> clone. In any other session (or with `--hyprland`) it is still the original project's Hyprland installer: it
> downloads the original MacShell, installs Hyprland packages and edits Hyprland's configuration. The graphical
> installer is Hyprland-only: don't run it on KDE Plasma.

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
              # optional features, one switch each (see "Optional features" above)
              features.pickers = true;            # kdialog: the Choose… buttons
              features.clipboardHistory = true;   # cliphist and wl-clipboard
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
| `lockScreen` | `false` | KDE's lock screen shows MacLock ([Lock screen](#lock-screen)). Applies from the next login. |
| `features.<name>` | `false`, `fileIcons`: `true` | Installs the programs of one [optional feature](#optional-features). |
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

### Arch Linux (PKGBUILD)

Untested. The package isn't in the AUR; build it from the repository:

```sh
git clone https://github.com/OngYean/MacShell-KWin
cd MacShell-KWin/packaging/arch
makepkg -si
```

This builds `macshell-kwin-git` from the repository's default branch and installs it under `/usr`, with Quickshell,
Qt 6 and KWayland as dependencies; the [optional features](#optional-features) are its optional dependencies,
which `makepkg -si` does not install. To build another branch, append `#branch=<name>` to the `source` line of the
`PKGBUILD`. Then see [After installing](#after-installing-without-nix). Remove it with
`macshell-session autostart off` followed by `sudo pacman -R macshell-kwin-git`.

### Any distribution: `install.sh`

Untested. Run it from a clone, inside your Plasma session (or pass `--kde`):

```sh
git clone https://github.com/OngYean/MacShell-KWin
cd MacShell-KWin
./install.sh                      # builds the bridge and installs everything into ~/.local
./install.sh --uninstall          # removes it again; your settings are kept
```

It needs Quickshell 0.3.x, Qt 6 (base, declarative, wayland, multimedia, svg), the development files for Qt 6,
KWayland and the Wayland client library, `wayland-scanner`, `wayland-protocols`, `wlr-protocols`, CMake, pkg-config
and a C++20 compiler. Package names differ between distributions. The script lists what it can't find and stops.
The only distribution packages it installs are those of the [optional features](#optional-features) you say yes
to, and it never edits KDE's configuration.

| Option | Effect |
| --- | --- |
| `--prefix DIR` | Install somewhere other than `~/.local`, for example `/usr/local`. The script uses `sudo` for the copy when it can't write there. Pass the same prefix to `--uninstall`. |
| `--autostart replace\|coexist\|off` | Also set what a Plasma login starts (see [After installing](#after-installing-without-nix)). |
| `--features LIST` | Choose the optional features without being asked: `all`, `none`, or names separated by commas. |
| `--features-only` | Only choose the optional features; nothing is built or installed otherwise. |
| `--uninstall` | Stop MacShell and bring `plasmashell` back, turn autostart off, and remove the installed files. Programs installed for optional features stay. |
| `--kde` / `--hyprland` | Choose the KDE install or the original Hyprland installer whatever the session is. |

What it puts under the prefix: `bin/macshell`, `bin/macshell-session`, `bin/macshell-kwin-bridge`,
`share/macshell/shell/` (the Quickshell configuration), `share/systemd/user/macshell.service` and
`macshell-fallback.service`, `share/kio/servicemenus/macshell-pin-folder.desktop` (Dolphin's "Pin to MacShell
Dock") and `share/plasma/shells/com.macshell.lock` (MacLock for KDE's lock screen, unused until you switch it on).
To update, `git pull` and run `./install.sh` again.

### By hand with CMake

Untested. `install.sh` and the Arch package run the same rules:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build build
sudo cmake --install build        # DESTDIR=... stages it for a package
```

`-DMACSHELL_BRIDGE=OFF` leaves `macshell-kwin-bridge` out, for packaging it separately from `kwin-bridge/`.
Nothing here installs the programs of the [optional features](#optional-features): install the ones you want.

### After installing without Nix

- **Start it:** `macshell-session start` runs MacShell in place of `plasmashell` for this login; see
  [Running it](#running-it). If `~/.local/bin` isn't on your `PATH`, add it or call
  `~/.local/bin/macshell-session`.
- **Start it at every Plasma login:** `macshell-session autostart replace` (in place of `plasmashell`),
  `autostart coexist` (next to it) or `autostart off`. It enables or disables `macshell.service` for Plasma
  sessions. For `replace` it also writes `~/.config/systemd/user/plasma-plasmashell.service.d/macshell.conf` and
  `~/.config/environment.d/macshell.conf`, the same two settings the Home Manager module makes: `plasmashell`
  skips itself at login, and is started again if MacShell fails three times within a minute. `plasmashell` is
  never masked or removed. Don't use this command with the Home Manager module.
- **Lock screen:** see [Lock screen](#lock-screen).

### From a clone, without installing

Untested. Nothing is installed except the bridge:

1. Install the same dependencies as for `install.sh`.
2. Build the bridge, install it into `~/.local/bin` (which must be on your `PATH`), and start the shell:

   ```sh
   git clone https://github.com/OngYean/MacShell-KWin
   cd MacShell-KWin
   cmake -S kwin-bridge -B build -DCMAKE_BUILD_TYPE=Release
   cmake --build build
   cmake --install build --prefix ~/.local
   qs -p ./MacShell                     # Ctrl+C stops it
   ```

This way there is no `macshell` or `macshell-session` command: use `qs -p /path/to/MacShell` in their place, and
see [Running it](#running-it) for the manual steps. For Dolphin's "Pin to MacShell Dock", copy
`nix/macshell-pin-folder.desktop` to `~/.local/share/kio/servicemenus/`, make the copy executable, and change its
`Exec=` line to `qs -p /path/to/MacShell ipc call dock pinFolder %f`.

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
  From a clone: `systemctl --user stop plasma-plasmashell.service`, then `MACSHELL_KDE_MODE=replace qs -p ./MacShell`.
  Undo it with `Ctrl+C`, then `systemctl --user start plasma-plasmashell.service`.
- **Coexist** (`macshell-session coexist`, or `mode = "coexist"`): `plasmashell` keeps its panels, desktop, pop-ups,
  clipboard history and, if it has a system tray, notifications. **Remove, move or auto-hide Plasma's top and bottom
  panels**, or they overlap MacShell's bar and Dock. MacShell's desktop takes the clicks meant for Plasma's desktop
  icons, so remove Plasma's or turn MacShell's off.

**Global menu:** Qt and GTK apps check once, at start, whether a global menu is available. Apps that were already
running before MacShell keep their own menu bar until you restart them.

### Lock screen

KDE's screen locker always locks the session, checks your password (and fingerprint, if you use one), locks when the
computer is idle or goes to sleep, and restarts the lock screen if it crashes. With `programs.macshell.lockScreen =
true` it draws MacLock instead of KDE's own screen. Not yet tested in a Plasma session.

- **How it is switched on.** The module installs a small Plasma package, `com.macshell.lock`, into
  `~/.local/share/plasma/shells/` and sets `PLASMA_DEFAULT_SHELL=com.macshell.lock` for your session. Log out and
  in again after rebuilding. `plasmashell` and the logout screen read the same variable; the package contains only
  a lock screen, so they take everything else from Plasma's own package.
- **Without Nix** (`install.sh`, the Arch package, CMake) the package is already installed, under
  `share/plasma/shells/` of the prefix. Switch it on by saving the line `PLASMA_DEFAULT_SHELL=com.macshell.lock`
  as `~/.config/environment.d/macshell-lock.conf` and logging out and in; delete the file to go back. Not yet
  tested.
- **Try it in a window first**, without locking anything:
  ```sh
  greet=$(nix-store -qR /run/current-system | grep -m1 -E -- '-kscreenlocker-[0-9][^/]*$')/libexec/kscreenlocker_greet
  "$greet" --testing --shell com.macshell.lock
  ```
  Your real password closes it. Before installing, `nix build .#macshell-lock` and pass
  `"$PWD/result/share/plasma/shells/com.macshell.lock"` to `--shell` instead.
- **With several screens** the clock, Now Playing and the password field go on the display chosen under MacShell's
  Settings → Displays → Main display while it is connected, else on the laptop's built-in panel, else on the first
  screen. The other screens show the wallpaper and the clock. Not yet tested.
- **KDE's own lock wallpaper is set to MacShell's.** KDE draws its lock wallpaper under MacLock, and that picture
  used to show for a moment before MacLock appeared. While MacLock is the lock screen, MacShell writes its
  wallpaper into KDE's setting (`kscreenlockerrc`, the picture under System Settings → Screen Locking →
  Appearance) at startup and whenever you change the wallpaper, so what shows first is the same picture. Your own
  choice there is overwritten; with `lockScreen` off nothing is written. Not yet tested.
- **If MacLock fails to load**, KDE shows its built-in fallback screen and your password still unlocks. If you are
  ever stuck, switch to a text console (Ctrl+Alt+F3), log in and run `loginctl unlock-session <id>` (`loginctl`
  lists the ids).
- **To go back**, set `lockScreen = false`, rebuild, and log out and in.
- **What you lose from KDE's own lock screen:** the Switch User, Sleep and Hibernate buttons, the on-screen
  keyboard and the keyboard layout switcher. The options under System Settings → Screen Locking → Appearance
  (wallpaper, clock, media controls) no longer apply; MacLock uses the wallpaper picked in MacShell and the
  settings under MacShell's Settings → Lock Screen.
- **Lyrics, Spotify Canvas and album covers from the internet** are fetched by helper programs (`curl`, `python3`,
  `jq`), because KDE's lock screen itself is not allowed to use the network. Without those tools on your `PATH`
  you only lose those features.

### Keyboard shortcuts

Bind MacShell's actions in System Settings → Keyboard → Shortcuts → Add New → Command or Script, for example
`Meta+Space` → `macshell ipc call spotlight toggle`. Running from a clone, use `qs -p /path/to/MacShell ipc call …`.
KWin's own task switcher stays on Alt+Tab.

| Target | Functions |
| --- | --- |
| `spotlight` | `toggle`, `clipboard`, `emoji`, `apps` |
| `screenshot` | `region`, `screen`, `window` (Spectacle on KDE) |
| `wallpapers` | `toggle`, `open`, `close` |
| `switcher` | `next`, `prev`, `commit`, `cancel` |
| `controlcenter` | `toggle`, `open`, `close` |
| `notifications` | `toggle`, `open`, `close`, `clear` |
| `settings` | `open` |
| `widgets` | `refresh` (re-fetch the weather), `edit true\|false` |
| `dock` | `pinFolder /path/to/folder` (what Dolphin's "Pin to MacShell Dock" runs) |

### KWin's blur

By default MacShell draws its glass itself. Liquid Glass blurs and bends a picture of the wallpaper, and the Normal
Blur style is a plain tint on KWin, so the windows behind a menu or the Dock don't show through.
**Settings → Appearance → Panels** (the blur choice is shown on KWin only) lets each panel hand the blur to KWin
instead. You can mix them: for example "Stock blur" for the Dock and "KWin blur" for everything else.

- The panels:
  - Dock: the Dock itself;
  - Dock labels and menu: the Dock's hover labels and its right-click menu. Until this row is used they follow the
    Dock's row;
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
| `~/.config/macbar/settings.json` | Menu bar settings, including the Apple menu's items (`appleMenuItems`) |
| `~/.config/macdock/settings.json`, `pinned.json` | Dock settings; pinned apps and folders (an entry starting with `/` is a folder) |
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
  widgets on other screens and the per-screen title and menus (`handoff/17-per-screen-tests.md`), nor MacLock as
  KDE's lock screen (`handoff/18-lock-screen-tests.md`), nor the memory changes (`handoff/19-memory-report.md`).
- **Memory:** Liquid Glass keeps a screen-sized backdrop for the bar and for the Dock on every screen. A panel set
  to KWin's blur (Settings → Appearance → Panels) has none, which is the largest saving you can make yourself.
- **MacLock as KDE's lock screen:** it uses the wallpaper picked in MacShell, so with no pick (for example next to
  `plasmashell` with Plasma's wallpaper) the background is dark. It fades in over KDE's lock wallpaper (kept the
  same picture as MacShell's), not over the desktop. Notifications and timers on it update every two seconds, the battery every thirty. An account
  without a password needs Enter to unlock.
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
Running from a clone, run `systemctl --user start plasma-plasmashell.service` after stopping MacShell. With
autostart in replace mode, the next login starts MacShell again. To get Plasma's shell at login, set
`mode = "coexist"` or `autostart = false` and rebuild (Home Manager), or run `macshell-session autostart off`
(other installs). To uninstall, set `programs.macshell.enable = false` (or remove the module) and rebuild; run
`./install.sh --uninstall`; or remove the Arch package. MacShell's settings stay in the folders listed above.

## Development

- `nix develop --command qs -p ./MacShell` runs the shell from the working tree with the bridge on `PATH`.
- `MACSHELL_KWIN_BRIDGE="$PWD/kwin-bridge/fake-bridge.py"` swaps in a fake bridge with made-up windows and menus,
  for testing the interface without KWin.
- `sh nix/test-macshell-session.sh`, `sh nix/test-brightness.sh` and `nix/kwin-smoke.sh` are among the tests CI
  runs; `sh nix/test-install.sh` checks the install outside Nix (CMake, the launcher, `install.sh --uninstall`).
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
