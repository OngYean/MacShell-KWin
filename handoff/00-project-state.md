# Project state and architecture baseline

This file is a standalone project brief. Use it with the repository's `AGENTS.md`, which is authoritative and contains the complete requirements and acceptance criteria. This is a handoff, not proof that the KWin port is complete.

## Goal

Port the existing macOS Tahoe-inspired MacShell Quickshell presentation to **KDE Plasma 6 Wayland with KWin**. Keep KWin as compositor, preserve Klassy/KDecoration3 and KDE desktop services, and eventually render real active-application Global Menus through KDE's AppMenu/D-BusMenu integration. Nix deployment should be reproducible, and the original Plasma desktop must remain recoverable.

The user is now in a standard Plasma 6 Wayland session. Local verification reports KWin and plasmashell `6.8.2`, Qt `6.12.0`, `XDG_SESSION_TYPE=wayland`, and `XDG_CURRENT_DESKTOP=KDE`. Do not alter host configuration, change sessions, run `install.sh`, install software, disable plasmashell, or use privileged commands.

## Repository and current state

- Project root: `MacShell-KWin/`.
- Current committed HEAD: `f9037d5` (`docs(handoff): refresh repository state references`). The initial source-audit baseline was `51db0bab6997da310d2aacfaa7084740ec44ad4a` (`Update MacShell files`, 2026-11-02); that commit is historical. The current POC and session updates are uncommitted.
- Main content: `MacShell/`, `MacLock/`, `MacInstaller/`, `hypr-macshell/`, `install.sh`, `README.md`, `LICENSE`.
- `MacShell/` is the checked-out upstream-derived Quickshell project. README identifies upstream as `0-ss/MacShell`; no separate KWin fork or upstream remote has been verified.
- There was no NixOS/Home Manager repository or flake in this workspace. The user now requests that this repository itself carry the development flake.
- User-provided `AGENTS.md` is tracked. Never overwrite, move or delete it.
- Packaging baseline: `flake.nix`, `flake.lock`, `PACKAGING.md`. The flake uses `nixos-unstable`, locked to Nixpkgs revision `0bb2eedc20e4739f29e8045034f2828ad7054f8f` dated 2026-11-01; Quickshell evaluates to `0.3.2`, and `pkgs.kdePackages.kwayland` evaluates to `6.8.2`. On 2026-11-02, the helper build and runtime checks passed in Plasma/KWin `6.8.2`. With KWrite confirmed active (`appId=org.kde.kwrite`), KWin advertised Plasma Window Management v21 and AppMenu; the active address settled to present and `--menu-check` retrieved D-BusMenu `GetLayout` with 8 root entries. The active KWrite process maps Qt's `libqwayland.so`, not `libqxcb.so`, so this is native Wayland; Xwayland remains untested. The new isolated renderer at `poc/global-menu/` consumes actual labels/tree; a sanitized helper check counted 8 root, 132 total and 96 labeled items without printing content. Bounded Quickshell runs loaded the fixture; the user visual check and event/activation path are still pending. The existing Hyprland shell package has not been built.
- The isolated panel/dock fixture at `poc/kwin-basics/` was visually accepted: its temporary top bar and inert dock appeared on `eDP-1`, disappeared after exit and did not shift application work areas. Keyboard behavior, hotplug/scaling and Klassy remain untested. `poc/kwin-backend-probe/` provides the diagnostic C++ helper and aggregate status fixture; its `--watch` mode contains sensitive window metadata, while `--menu-check` prints only layout result and root-item count. The new `poc/global-menu/` renderer decodes the real D-BusMenu tree and has a local validated `Event` bridge; labels stay inside the helper-to-QML pipe. A sanitized check returned 8 root / 132 total / 96 labeled items. The renderer loaded in bounded Quickshell runs with no QML diagnostics; user visual verification of this menu fixture and runtime Event/activation tests are pending. The user confirms Plasma's native Global Menu widget displays KWrite's real menu. The basic backend and menu fixtures are separate; neither is integrated into production MacShell. A KWin script probe was loaded as ID `1`, invoked through `/Scripting/Script1`, and unloaded; its `console.info` output was not observable, so script-side window data remains unverified. An earlier test mistakenly invoked `/Scripting/Script0` instead of the returned ID; no existing script was stopped/unloaded and no persistent setting changed.
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

The branch carries untested implementations for Milestones 3–6. They were written without a Plasma session, Nix or Qt; only syntax parsers ran. See [`05-kwin-port.md`](05-kwin-port.md) for what was built and [`06-kwin-testing-guide.md`](06-kwin-testing-guide.md) for how to test it.

- **M3 compositor abstraction:** `MacShell/backends/compositor/` (facade + Hyprland and KWin backends). All UI compositor access goes through `hub.compositor`; Hyprland-only features are gated by `can(...)`.
- **M3 KWin backend:** `kwin-bridge/` (`macshell-kwin-bridge`), promoted from the POC. It is event-driven, validates its input, and keeps titles and labels in the pipe. Plasma Window Management stays isolated in this helper, with the decision record and version/fallback policy in its README; this closes the trust/access review the earlier briefs asked for.
- **M4 global menu:** a real D-BusMenu renderer in `MacBar.qml`, falling back to the generic menus. The bridge registers `org.kde.kappmenuview` so the registrar survives without Plasma's applet.
- **M5 integration:** dock, menu bar, session actions (KDE locker, `org.kde.Shutdown`), workspaces, keyboard layouts, Spectacle for screenshots/recording, KDE settings modules for displays/input/Night Light, no live capture on KWin, and notifications only in an explicit replace mode.
- **M6 Nix:** `packages.macshell`, `packages.macshell-kwin-bridge`, `apps.macshell-session` (per-login `replace` / `restore`), `homeManagerModules.macshell` (autostart off by default; plasmashell never disabled).

## Milestones and status

1. **Architecture audit:** source-level audit identified major Hyprland couplings and Global Menu transport. Installed versions are confirmed as Plasma/KWin `6.8.2`, Qt `6.12.0`, and Quickshell `0.3.2` from the dev flake.
2. **Minimal KWin proof of concept:** the isolated layer-shell top bar and inert dock in `poc/kwin-basics/` were visually confirmed by the user on `eDP-1`; they disappear on exit and do not change application work areas. Keyboard behavior, hotplug/scaling and Klassy behavior remain unverified. Native plasmashell remains running. KWin is configured for Breeze, not Klassy.
3. **Compositor abstraction:** only a diagnostic read-only KWin protocol helper and QML status fixture exist. This is not a production abstraction; activation, state-changing operations, output management and previews remain unsupported. Do not begin broad rewrites before trust boundaries, access mechanisms and supported APIs are pinned.
4. **Global Menu proof of concept:** KWin advertises AppMenu, native-Wayland KWrite eventually registers an address, and the helper retrieves the actual D-BusMenu tree (8 root / 132 total / 96 labeled items, sanitized counts). The user confirms Plasma's native widget displays KWrite's real menu. An isolated Quickshell renderer with nested popups and a validated D-BusMenu Event bridge exists in `poc/global-menu/`; bounded runtime loading passed, but user visual verification and Event/leaf activation testing remain pending.
5. **Full integration:** not started. Preserve KDE services, native locking and Klassy.
6. **Nix deployment:** only a development packaging baseline exists; no KWin deployment/autostart, system module, or session switching has been implemented.

## Non-negotiable safety and design constraints

- Retain KWin and Klassy; never introduce competing application decorations.
- Do not disable plasmashell or KDE services prematurely. Avoid duplicate tray, notification, lock, portal or session components.
- Keep UI separate from compositor/KDE adapters. Unsupported features must be explicitly reported, not silently faked.
- Avoid private or desktop-only interfaces from untrusted clients without documented access justification.
- Do not run privileged installation/configuration commands or modify the user's host configuration. Preserve a rollback path.
- Test Quickshell panel/dock, actual Global Menus, native Wayland and Xwayland apps, multi-display, sleep/resume and hybrid-GPU behavior in the target session before claiming support.
