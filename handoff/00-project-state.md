# Project state and architecture baseline

This file is a standalone project brief. Use it with the repository's `AGENTS.md`, which is authoritative and contains the complete requirements and acceptance criteria. This is a handoff, not proof that the KWin port is complete.

## Goal

Port the existing macOS Tahoe-inspired MacShell Quickshell presentation to **KDE Plasma 6 Wayland with KWin**. Keep KWin as compositor, preserve Klassy/KDecoration3 and KDE desktop services, and eventually render real active-application Global Menus through KDE's AppMenu/D-BusMenu integration. Nix deployment should be reproducible, and the original Plasma desktop must remain recoverable.

The user is now in a standard Plasma 6 Wayland session. Local verification reports KWin and plasmashell `6.8.2`, Qt `6.12.0`, `XDG_SESSION_TYPE=wayland`, and `XDG_CURRENT_DESKTOP=KDE`. Do not alter host configuration, change sessions, run `install.sh`, install software, disable plasmashell, or use privileged commands.

## Current state (2026-11-05)

This section supersedes older status lines further down where they disagree. The older lines are kept for history.

- **Repository:** `github.com/OngYean/MacShell-KWin`, a public fork of `0-ss/MacShell` based on `51db0ba`. Its `LICENSE` credits both the original author and the port.
- **Branches:**
  - `main` (`d53665e`) already contains `kwin-port`.
  - `kwin-plasma-fixes` (`701c526`) is based on `main`.
  - `fork-credits-readme` (`2644f5c`) is based on `kwin-plasma-fixes`.
  - `kwin-replace-wallpaper-splash` is based on `fork-credits-readme`.
  - `kwin-magic-lamp` is based on `kwin-replace-wallpaper-splash`: Magic Lamp minimizes into the Dock ([`13`](13-magic-lamp-tests.md)).
  - **`pending-test`** is the staging branch: everything above, merged (fast-forwards, since the branches are stacked), plus commits made straight to it. These are sharp menu bar icons ([`14`](14-sharp-bar-icons-tests.md)) and two CI fixes for the Home Manager check. It is the branch to test and fix on in Plasma, before it goes into `main`.
  - Every branch is pushed. CI passes on `pending-test` (`3abdc32`). It fails on `kwin-replace-wallpaper-splash` and `kwin-magic-lamp`, whose Home Manager check predates the CI fixes on `pending-test`. `kwin-plasma-fixes` and `fork-credits-readme` last passed on 2026-11-04, before Home Manager's `master` changed; a re-run would likely fail the same check. See [`README.md`](README.md).
- **Direction (user decision, 2026-11-05):** MacShell runs **in place of `plasmashell` by default**, and side by side is the second option. Three untested features on `kwin-replace-wallpaper-splash` implement it:
  - the wallpaper and login splash without `plasmashell` ([`10`](10-replace-wallpaper-splash-tests.md));
  - "Use KWin's blur" ([`11`](11-kwin-blur-tests.md));
  - replace as the default launch and the Home Manager `mode` ([`12`](12-replace-default-tests.md)).

  Agents still don't change the host's configuration themselves. The user opts in through Home Manager.
- **Since then, on `pending-test`, untested in Plasma:**
  - KWin's Magic Lamp animates into each window's Dock icon instead of towards the pointer. The bridge (0.2.0) registers the targets against its own invisible per-output layer surfaces. CI confirms that KWin reports them as `iconGeometry` ([`13`](13-magic-lamp-tests.md)).
  - The menu bar's Canvas icons are painted at the scale they're shown at, and repainted when the display scale changes, so they're no longer blurry at UI scales other than 100 % ([`14`](14-sharp-bar-icons-tests.md)).
- **Still missing without `plasmashell`** (checked against the Plasma 6.8.2 sources; none of it ported yet):
  - **Tray entries:**
    - Night Light on/off (the button only opens System Settings), keyboard backlight, the list of apps blocking sleep;
    - Disks & Devices (no mount or eject menu; kded's automount still works);
    - Display Configuration (layout switch, presentation mode);
    - KDE Connect (`kdeconnect-indicator` would show in MacShell's tray);
    - Printers, Vaults, Input Method, Lock Keys and Dwell Clicker.
  - **Other `plasmashell` duties:**
    - notifications from Flatpak and other sandboxed apps: the portal backend `plasmanotify` runs inside `plasmashell` (`kde-portals.conf`);
    - file-transfer progress (`org.kde.JobViewServer`);
    - pop-ups other than volume and brightness (`org.kde.osdService`), such as the muted-microphone reminder. The volume keys themselves stay working, because they're in plasma-pa's kded module;
    - `Meta` alone, which KWin sends to Plasma's launcher;
    - Klipper's clipboard history, replaced by `cliphist`, so `Meta+V` needs rebinding;
    - the activity switcher and `Meta+1…9`.
- **Coexist and notifications:** once any Plasma Notifications applet has loaded, `plasmashell` keeps `org.freedesktop.Notifications` until it exits. `libnotificationmanager`'s server is a process-wide singleton that never unregisters the name, and it registers it with `DontAllowReplacement`. So MacShell's 15 s takeover only works if no such applet ever loaded in that `plasmashell` process. Replace mode avoids the problem.
- **Global Menu:** the user reports that the AppMenu export problem is fixed in their Plasma 6.8.2 session: real application menus now reach MacShell's bar. The "hidden yet clickable, mock items" failure described below is therefore out of date.
- **Bugs reported after that fix:** six (bar background, force blur, brightness, notifications without a Plasma tray, wallpaper sync, menu icons). Each has a `wip` fix on `kwin-plasma-fixes`, none tested in Plasma. See [`08-plasma-fixes-tests.md`](08-plasma-fixes-tests.md).
- **Fork housekeeping on `fork-credits-readme`:**
  - licence and credit notices, and a README written for installing on Plasma;
  - the update check now uses this fork;
  - the Apple logo trademark notice;
  - removal of leftover upstream files.

  See [`09-fork-credits-readme.md`](09-fork-credits-readme.md). `README.md` is now the user-facing install guide, and `AGENTS.md` §11 rule 15 requires its list of changes from upstream to stay current.
- **Nix (M6):** `packages.macshell`, `packages.macshell-kwin-bridge`, `apps.macshell-session` and `homeManagerModules.macshell` all exist. The Home Manager module's autostart is off by default. With autostart, `mode = "replace"` (the default since 2026-11-05) makes `plasma-plasmashell.service` skip itself at login through a drop-in condition, never a mask, and a fallback unit starts it again if MacShell keeps failing. They build and evaluate in CI. The user runs MacShell from this flake, but the README's Home Manager steps have not been followed on a real machine.
- **Still unverified:**
  - Klassy (KWin was set to Breeze);
  - GTK, Electron, Firefox and VS Code menus, and menus of Xwayland apps;
  - multi-monitor use and display hotplug;
  - sleep and resume;
  - GPU wakeups;
  - Hyprland at runtime.
- **Dev machine:** macOS without Nix, Qt or Plasma. All runtime testing happens on the user's NixOS Plasma host.

## Repository and earlier state

- Project root: `MacShell-KWin/`.
- Current committed HEAD: `f9037d5` (`docs(handoff): refresh repository state references`). The initial source-audit baseline was `51db0bab6997da310d2aacfaa7084740ec44ad4a` (`Update MacShell files`, 2026-11-02); that commit is historical. The current POC and session updates are uncommitted.
- Main content: `MacShell/`, `MacLock/`, `MacInstaller/`, `hypr-macshell/`, `install.sh`, `README.md`, `LICENSE`.
- `MacShell/` is the checked-out upstream-derived Quickshell project. README identifies upstream as `0-ss/MacShell`; no separate KWin fork or upstream remote has been verified.
- There was no NixOS/Home Manager repository or flake in this workspace. The user now requests that this repository itself carry the development flake.
- User-provided `AGENTS.md` is tracked. Never overwrite, move or delete it.
- Packaging baseline: `flake.nix`, `flake.lock`, `PACKAGING.md`. The flake uses `nixos-unstable`, locked to Nixpkgs revision `0bb2eedc20e4739f29e8045034f2828ad7054f8f` dated 2026-11-01; Quickshell evaluates to `0.3.2`, and `pkgs.kdePackages.kwayland` evaluates to `6.8.2`. See `05-kwin-port.md` for CI validation and the integrated live-test state. In the user's Plasma/KWin `6.8.2` Wayland session, latest testing reports the shell runs casually but the production Global Menu is currently hidden yet clickable and shows mock/generic items instead of exported app menus; apps with AppMenu support are rendering their own in-window menus, suggesting they are not detecting the global-menu registration. Earlier reports of KWrite/Dolphin display and action success are superseded by this latest reproduction. A mnemonic-normalization change is present but cannot be visually verified against real labels until AppMenu registration/import works.
- The isolated panel/dock fixture at `poc/kwin-basics/` was visually accepted: its temporary top bar and inert dock appeared on `eDP-1`, disappeared after exit and did not shift application work areas. Keyboard behavior, hotplug/scaling and Klassy remain untested. `poc/kwin-backend-probe/` provides the diagnostic C++ helper and aggregate status fixture; its `--watch` mode contains sensitive window metadata, while `--menu-check` prints only layout result and root-item count. The original `poc/global-menu/` renderer was a research prototype; production MacShell now has the real D-BusMenu renderer described in `05-kwin-port.md`. Latest user testing contradicts earlier reports: the production menu is hidden yet clickable, shows mock/generic items, and apps with AppMenu still render in-window menus. Mnemonic underscores are normalized in production QML but have not been verified with real app labels. Do not confuse old POC limitations/status below with the current integrated implementation.
- KWin's D-Bus `supportInformation` and `kwinrc` both report decoration plugin `org.kde.breeze` / `Breeze`, not Klassy. Do not alter this user setting; Klassy-specific verification is blocked until it is installed/selected by the user.

## Source-level dependency inventory

### Reusable subject to KWin testing

Most visual QML, icons, fonts, shaders, application listing, and generic widgets are presentation code and are candidates for reuse. Several Quickshell services (media, power, audio, network, notification, etc.) are compositor-independent in principle, but service ownership must be reviewed so KDE does not end up with duplicate notification or tray daemons.

### Needs compositor/KDE integration

- `MacShell/shell.qml`: imports `Quickshell.Hyprland`, polls `hyprctl` JSON for monitors/clients, consumes Hyprland IPC, and uses Hyprland state for geometry/capture gating.
- `MacShell/MacBar.qml`: Hyprland Lua dispatch and `hyprctl` for window/workspace/input/session operations, keyboard layout and active-window context.
- `MacShell/MacDock.qml`: uses Quickshell `ToplevelManager` for toplevel listing/activation and uses Hyprland-specific behavior for window move/resize/floating and tear-off interactions. Current Quickshell `ToplevelManager` is wlroots foreign-toplevel-management based; KWin does not expose that protocol in the inspected current source.
- Window capture/previews: MacShell's current top-level capture path uses Hyprland-specific export behavior. KWin screencasting support is not evidence that this per-window path works. Keep previews optional and avoid unconditional capture, especially on hybrid AMD/NVIDIA hardware.
- `AboutApp.qml` and settings-window logic in `MacDock.qml`: window size/floating/maximize/border behavior is sent through Hyprland Lua.
- `MacLock/shell.qml`: Quickshell session-lock presentation plus Hyprland monitor/Caps Lock state, `/etc/pam.d/hyprlock`, and Hyprland-specific recovery assumptions. Do not replace KDE's native lock screen until a secure, tested alternative exists.
- `install.sh`: package-manager/service setup, Hyprland config/keybind/autostart and Hyprland-specific helpers. It defaults to upstream `0-ss/MacShell` behavior and is not a KWin installer. Do not run it for this port.

## KWin and Global Menu facts from current upstream source

Treat these as source-review findings, not complete verification against the installed release. The session is KWin/Plasma `6.8.2`; pin relevant source and API behavior to that release before relying on upstream `master`.

- KWin implements `org_kde_kwin_appmenu_manager` / `org_kde_kwin_appmenu`. The client associates a `wl_surface` with a session-bus service name and object path. This is address registration, not the menu tree itself.
- Actual menu content is exposed through the `com.canonical.dbusmenu` D-Bus interface.
- Plasma's native Global Menu applet reads active-window menu service/path roles through Task Manager, imports the remote menu with KDE's `DBusMenuImporter`, and renders the resulting menu. This is the safest early renderer to retain while plasmashell remains running.
- KWin's `org_kde_plasma_window_management` protocol carries window state and app-menu service/path data, but its own XML calls it a privileged desktop-environment implementation detail and says regular clients must not use it. The protocol XML also says only one client may bind. In KWin 6.8.2 source, the server bind handler fans state out to its resource list without an obvious single-client rejection, while `wayland_server.cpp` filters the global for sandboxed clients; non-sandboxed clients are not filtered at that gate. The diagnostic successfully bound in the live session while the plasmashell process was confirmed running; whether plasmashell itself held a binding was not independently inspected. This remains a version-specific observation, not a stable access guarantee.
- KWin current source supports `wlr-layer-shell-v1`, making basic panel/dock layer placement plausible, but it still requires a target-session test.
- Quickshell current source has `Quickshell.DBusMenu`, primarily documented for system tray use. Its existing QML handle is not a direct arbitrary-service/path factory; the current parser handles nested items, updates, activation, separators, enabled/visible state, icons and check/radio state but does not parse menu shortcuts. Do not call it a complete global-menu renderer without closing those gaps.

Useful source links:

- [KWin AppMenu implementation](https://github.com/KDE/kwin/blob/master/src/wayland/appmenu.cpp)
- [KDE AppMenu protocol](https://github.com/KDE/plasma-wayland-protocols/blob/master/src/protocols/appmenu.xml)
- [KDE Plasma Window Management protocol](https://github.com/KDE/plasma-wayland-protocols/blob/master/src/protocols/plasma-window-management.xml)
- [Plasma Global Menu model](https://github.com/KDE/plasma-workspace/blob/master/applets/appmenu/appmenumodel.cpp)
- [Plasma Global Menu QML](https://github.com/KDE/plasma-workspace/blob/master/applets/appmenu/qml/main.qml)
- [Quickshell D-BusMenu source](https://github.com/quickshell-mirror/quickshell/tree/master/src/dbus/dbusmenu)

## Update: `kwin-port` branch (2026-11-03)

The branch carries implementations for Milestones 3–6. CI builds them, evaluates the Home Manager module, and runs the bridge and MacShell against a headless KWin 6.8.2; the user has also tested the integrated shell in a real Plasma/KWin session. Global Menu display and actions were confirmed with KWrite and Dolphin. See [`05-kwin-port.md`](05-kwin-port.md) for implementation and known gaps and [`06-kwin-testing-guide.md`](06-kwin-testing-guide.md) for the remaining test plan.

- **M3 compositor abstraction:** `MacShell/backends/compositor/` (facade + Hyprland and KWin backends). All UI compositor access goes through `hub.compositor`; Hyprland-only features are gated by `can(...)`.
- **M3 KWin backend:** `kwin-bridge/` (`macshell-kwin-bridge`), promoted from the POC. It is event-driven, validates its input, and keeps titles and labels in the pipe. Plasma Window Management stays isolated in this helper, with the decision record and version/fallback policy in its README; this closes the trust/access review the earlier briefs asked for.
- **M4 global menu:** a real D-BusMenu renderer in `MacBar.qml`, falling back to the generic menus. The bridge registers `org.kde.kappmenuview` so the registrar survives without Plasma's applet.
- **M5 integration:** dock, menu bar, session actions (KDE locker, `org.kde.Shutdown`), workspaces, keyboard layouts, Spectacle for screenshots/recording, KDE settings modules for displays/input/Night Light, no live capture on KWin, and notifications only in an explicit replace mode.
- **M6 Nix:** `packages.macshell`, `packages.macshell-kwin-bridge`, `apps.macshell-session` (per-login `start` = replace, the default, / `coexist` / `stop`), `homeManagerModules.macshell` (autostart off by default; with autostart, `mode = "replace"` by default skips plasmashell at login through a drop-in condition, never a mask, with a fallback that starts it again if MacShell keeps failing; see [`12-replace-default-tests.md`](12-replace-default-tests.md)).

## Milestones and status

1. **Architecture audit:** source-level audit identified major Hyprland couplings and Global Menu transport. Installed versions are confirmed as Plasma/KWin `6.8.2`, Qt `6.12.0`, and Quickshell `0.3.2` from the dev flake.
2. **Minimal KWin proof of concept:** the isolated layer-shell top bar and inert dock in `poc/kwin-basics/` were visually confirmed by the user on `eDP-1`; they disappear on exit and do not change application work areas. Keyboard behavior, hotplug/scaling and Klassy behavior remain unverified. Native plasmashell remains running. KWin is configured for Breeze, not Klassy.
3. **Compositor abstraction:** implemented in `MacShell/backends/compositor/` with `kwin-bridge/`; see `05-kwin-port.md`. KWin window/workspace interactions have passed headless smoke checks, with broader live-system coverage still in progress.
4. **Global Menu:** production implementation exists in `MacShell/MacBar.qml`. **2026-11-04:** the user reports the export problem below is fixed. Menu item icons have an untested fix on `kwin-plasma-fixes`. Earlier, the live test failed: its menu presentation is invisible yet clickable and contains mock/generic items, while apps with AppMenu support still show in-window menus. Investigate registration/import and visibility before claiming this milestone validated. Mnemonic marker cleanup is implemented but real-label behavior remains unverified. GTK/Electron/Firefox/VS Code and Xwayland remain untested.
5. **Full integration:** implemented to the extent documented in `05-kwin-port.md`; continue preserving KDE services, native locking and Klassy.
6. **Nix deployment:** `packages.macshell`, `apps.macshell-session` (per-login replace/restore) and `homeManagerModules.macshell` (opt-in autostart) are implemented and evaluated in CI. `README.md` documents the install. The Home Manager install has not been verified on a real machine. No NixOS system module exists, and none is planned.

## Non-negotiable safety and design constraints

- Retain KWin and Klassy; never introduce competing application decorations.
- Do not disable plasmashell or KDE services prematurely. Avoid duplicate tray, notification, lock, portal or session components.
- Keep UI separate from compositor/KDE adapters. Unsupported features must be explicitly reported, not silently faked.
- Avoid private or desktop-only interfaces from untrusted clients without documented access justification.
- Do not run privileged installation/configuration commands or modify the user's host configuration. Preserve a rollback path.
- Test Quickshell panel/dock, actual Global Menus, native Wayland and Xwayland apps, multi-display, sleep/resume and hybrid-GPU behavior in the target session before claiming support.
