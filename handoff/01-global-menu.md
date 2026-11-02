# Independent task: KDE Global Menu path

This brief is self-contained. Read the repository `AGENTS.md` before work; it is authoritative. The objective is a **real active-application menu**, not a hand-built/static lookalike.

## Context

The project is MacShell, an upstream-derived Quickshell shell currently coupled to Hyprland. The target is the latest upstream Plasma 6 Wayland/KWin, retaining KWin, Klassy and KDE services. The user is still in Hyprland and will enable Plasma in their host configuration themselves; they will notify us when the target session is active. Do not alter the host, change sessions, install packages or run installers.

Current repo HEAD is `bcadc79` (`docs(agents): add Git commit and validation rules`); the source-audit baseline was `51db0bab6997da310d2aacfaa7084740ec44ad4a` and is historical. No global-menu code has been changed. A development flake exists but does not solve Global Menu. Use upstream `master` only for discovery; pin actual source to target KWin/Plasma/Quickshell revisions once known.

## Verified source-level observations

1. KDE's [AppMenu Wayland protocol](https://github.com/KDE/plasma-wayland-protocols/blob/master/src/protocols/appmenu.xml) lets an app link a `wl_surface` to a D-Bus service name and object path. KWin's [implementation](https://github.com/KDE/kwin/blob/master/src/wayland/appmenu.cpp) tracks that address against the surface. The protocol does **not** transport the menu tree.
2. The actual menu model is via the [Canonical D-BusMenu protocol](https://github.com/AyatanaIndicators/libdbusmenu/blob/master/libdbusmenu-glib/dbus-menu.xml): layout/property retrieval and events use the app's registered service/object path.
3. Plasma's [Global Menu model](https://github.com/KDE/plasma-workspace/blob/master/applets/appmenu/appmenumodel.cpp) reads active-task `ApplicationMenuServiceName` and `ApplicationMenuObjectPath` roles, imports the menu with KDE `DBusMenuImporter`, and handles active-window/service changes. Its [QML applet](https://github.com/KDE/plasma-workspace/blob/master/applets/appmenu/qml/main.qml) renders the model. The applet is a useful native comparison and temporary POC renderer.
4. KWin's separate [`org.kde.kappmenu` XML](https://github.com/KDE/kwin/blob/master/src/org.kde.kappmenu.xml) has `showMenu`, `showRequest`, `menuShown` and `menuHidden` coordination operations. It is not the DBusMenu tree transport; confirm consumers/registration on the target release before using it.
5. Quickshell current source has a [`Quickshell.DBusMenu` module](https://github.com/quickshell-mirror/quickshell/tree/master/src/dbus/dbusmenu), documented as used in the system tray. Current implementation retrieves menu layout, lazy-loads nested children, processes property updates and sends opened/closed/clicked events. The exposed menu handle is not currently a direct arbitrary-service/path QML factory. Current property parsing covers separators, visible/enabled, labels, icons and check/radio state, but not keyboard shortcuts. It is a potential reusable implementation base, not a drop-in global-menu renderer.
6. KWin's [Plasma Window Management XML](https://github.com/KDE/plasma-wayland-protocols/blob/master/src/protocols/plasma-window-management.xml) includes app-menu service/path events, but labels the protocol as a desktop-environment implementation detail and warns regular clients not to use it. KWin current source has client restrictions. Establish whether a Quickshell shell client can safely obtain active-window menu addresses before choosing a renderer API.

## Work requested

Produce a source-backed integration assessment; do not implement a mock menu or claim application support without tests.

- Trace the latest-source AppMenu Wayland registration, KWin window association, app-side KDE/GTK/Qt registration and the native Plasma Global Menu path. Identify what is protocol/API contract versus implementation detail.
- Establish where the app-menu service/path for the active window can be obtained by a replacement shell without relying on unsupported client access. Compare the options: retain native Plasma applet temporarily; a KWin script/helper with narrow D-Bus API; another explicitly supported interface. Document trust/security and version dependencies.
- Inspect whether the current Quickshell DBusMenu module can be consumed from QML or only through existing service APIs. If an extension is needed, describe the smallest isolated API surface; do not modify broad UI files.
- Inventory missing renderer semantics: item hierarchy, separators, disabled/checkable/radio, shortcuts, mnemonics, icons, dynamic updates, nested menu open/close, activation and active-window races.
- Define a test matrix for Qt, GTK, Electron, Firefox and VS Code, splitting native Wayland and Xwayland when applicable. Mark each item untested until actually verified in Plasma.
- Specify how to compare a Quickshell renderer against Plasma's native Global Menu widget.

## Constraints / output

- Keep plasmashell and its native Global Menu widget available until a standalone renderer is proven.
- No host-session changes, privileged commands, package installation, duplicate global-menu watcher or notification/tray daemon.
- Do not use ordinary Quickshell binding of `org_kde_plasma_window_management` as a default until the security/version question is resolved.
- Do not edit `MacBar.qml` to substitute synthesized application menus for real exported menus.
- Deliver a concise report with sequence diagram, protocol ownership, compatibility matrix, chosen POC path, source links and open blockers. State which source revision each fact came from.
