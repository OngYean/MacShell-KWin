# Project state and architecture baseline

This file is a standalone project brief. Use it with the repository's `AGENTS.md`, which is authoritative and contains the complete requirements and acceptance criteria. This is a handoff, not proof that the KWin port is complete.

## Goal

Port the existing macOS Tahoe-inspired MacShell Quickshell presentation to **KDE Plasma 6 Wayland with KWin**. Keep KWin as compositor, preserve Klassy/KDecoration3 and KDE desktop services, and eventually render real active-application Global Menus through KDE's AppMenu/D-BusMenu integration. Nix deployment should be reproducible, and the original Plasma desktop must remain recoverable.

The current runtime is Hyprland. The user will enable `services.desktopManager.plasma6.enable` in their host configuration themselves and notify us after entering a standard Plasma Wayland session. Until then, do not alter host configuration, change sessions, run `install.sh`, install software, disable plasmashell, or use privileged commands.

## Repository and current state

- Project root: `MacShell-KWin/`.
- Current HEAD: `51db0bab6997da310d2aacfaa7084740ec44ad4a` (`Update MacShell files`, 2026-11-02).
- Main content: `MacShell/`, `MacLock/`, `MacInstaller/`, `hypr-macshell/`, `install.sh`, `README.md`, `LICENSE`.
- `MacShell/` is the checked-out upstream-derived Quickshell project. README identifies upstream as `0-ss/MacShell`; no separate KWin fork or upstream remote has been verified.
- There was no NixOS/Home Manager repository or flake in this workspace. The user now requests that this repository itself carry the development flake.
- User-provided `AGENTS.md` is currently untracked. Never overwrite, move or delete it.
- New packaging baseline: `flake.nix`, `flake.lock`, `PACKAGING.md`. The flake uses `nixos-unstable`, locked to Nixpkgs revision `0bb2eedc20e4739f29e8045034f2828ad7054f8f` dated 2026-11-01; Quickshell in that revision evaluates to `0.3.2`. Evaluation-only check passed for x86_64-linux and aarch64-linux. The package was not built or run.
- No source port, Global Menu renderer, backend, or KWin runtime verification has been done.

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

Treat these as source-review findings, not local runtime verification; re-pin them against the target versions once the user's Plasma session is known.

- KWin implements `org_kde_kwin_appmenu_manager` / `org_kde_kwin_appmenu`. The client associates a `wl_surface` with a session-bus service name and object path. This is address registration, not the menu tree itself.
- Actual menu content is exposed through the `com.canonical.dbusmenu` D-Bus interface.
- Plasma's native Global Menu applet reads active-window menu service/path roles through Task Manager, imports the remote menu with KDE's `DBusMenuImporter`, and renders the resulting menu. This is the safest early renderer to retain while plasmashell remains running.
- KWin's `org_kde_plasma_window_management` protocol carries window state and app-menu service/path data, but its own XML says it is a desktop-environment implementation detail and regular clients must not use it; KWin also restricts sandboxed clients in current source. Do not assume an ordinary Quickshell client may use it.
- KWin current source supports `wlr-layer-shell-v1`, making basic panel/dock layer placement plausible, but it still requires a target-session test.
- Quickshell current source has `Quickshell.DBusMenu`, primarily documented for system tray use. Its existing QML handle is not a direct arbitrary-service/path factory; the current parser handles nested items, updates, activation, separators, enabled/visible state, icons and check/radio state but does not parse menu shortcuts. Do not call it a complete global-menu renderer without closing those gaps.

Useful source links:

- [KWin AppMenu implementation](https://github.com/KDE/kwin/blob/master/src/wayland/appmenu.cpp)
- [KDE AppMenu protocol](https://github.com/KDE/plasma-wayland-protocols/blob/master/src/protocols/appmenu.xml)
- [KDE Plasma Window Management protocol](https://github.com/KDE/plasma-wayland-protocols/blob/master/src/protocols/plasma-window-management.xml)
- [Plasma Global Menu model](https://github.com/KDE/plasma-workspace/blob/master/applets/appmenu/appmenumodel.cpp)
- [Plasma Global Menu QML](https://github.com/KDE/plasma-workspace/blob/master/applets/appmenu/qml/main.qml)
- [Quickshell D-BusMenu source](https://github.com/quickshell-mirror/quickshell/tree/master/src/dbus/dbusmenu)

## Milestones and status

1. **Architecture audit:** source-level audit has identified major Hyprland couplings and the Global Menu transport. Installed KWin/Plasma/Quickshell versions and target-session behavior remain unverified.
2. **Minimal KWin proof of concept:** not started. Wait for the user's Plasma-session signal. Keep plasmashell and native Global Menu; do not overlap panels.
3. **Compositor abstraction:** not started. Do not begin broad rewrites before access mechanisms and supported APIs are pinned.
4. **Global Menu proof of concept:** research only so far; no actual menu rendered or app tested.
5. **Full integration:** not started. Preserve KDE services, native locking and Klassy.
6. **Nix deployment:** only a development packaging baseline exists; no KWin deployment/autostart, system module, or session switching has been implemented.

## Non-negotiable safety and design constraints

- Retain KWin and Klassy; never introduce competing application decorations.
- Do not disable plasmashell or KDE services prematurely. Avoid duplicate tray, notification, lock, portal or session components.
- Keep UI separate from compositor/KDE adapters. Unsupported features must be explicitly reported, not silently faked.
- Avoid private or desktop-only interfaces from untrusted clients without documented access justification.
- Do not run privileged installation/configuration commands or modify the user's host configuration. Preserve a rollback path.
- Test Quickshell panel/dock, actual Global Menus, native Wayland and Xwayland apps, multi-display, sleep/resume and hybrid-GPU behavior in the target session before claiming support.
