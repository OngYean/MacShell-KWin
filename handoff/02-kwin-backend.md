# Independent task: KWin compositor/backend assessment

This brief is self-contained. Read the repository `AGENTS.md` first; it is the project authority. The goal is a stable UI/backend boundary, not an early broad rewrite of the MacShell QML.

## Context and current state

MacShell in this workspace is still upstream-derived and Hyprland-dependent. It is intended for latest upstream Plasma 6 Wayland with KWin, while retaining Klassy/KDecoration3 and KDE services. The user is now in Plasma/KWin `6.8.2` Wayland with Qt `6.12.0`; Quickshell `0.3.2` is available in the repository dev shell. Do not alter host configuration, switch sessions, install software, run installers, or disable KDE components. The active decoration is Breeze (`org.kde.breeze`), not Klassy.

Current source audit:

- `MacShell/shell.qml` imports `Quickshell.Hyprland`, polls `hyprctl` JSON/IPC and derives monitor/client state from Hyprland.
- `MacShell/MacBar.qml` sends Hyprland Lua/CLI commands for window/workspace/input/session operations.
- `MacShell/MacDock.qml` uses Quickshell `ToplevelManager`, current-source implementation backed by wlroots foreign-toplevel management, and Hyprland-specific window rules/actions.
- KWin current source did not advertise wlr foreign-toplevel management. Do not assume this Quickshell manager will enumerate KWin windows.
- KWin's Plasma Window Management protocol contains rich window/workspace information and requests, but its XML calls it a privileged desktop-environment implementation detail, says regular clients must not use it, and says only one client may bind. In KWin `v6.8.2`, the server bind handler populates each resource without an obvious one-client rejection; the Wayland server filters this global for sandboxed clients, while non-sandboxed clients pass that gate. The diagnostic bound successfully in the live session while plasmashell was running, but whether plasmashell itself was bound was not independently established. This is implementation-specific and not a public access guarantee.
- KWin source review identified layer-shell v1 support. In the local `6.8.2` Wayland session, the isolated Quickshell 0.3.2 panel/dock fixture targeted `eDP-1 1920x1080`; the user visually confirmed the temporary surfaces appear as expected, disappear after exit, and do not shift application work areas. This does not verify Klassy, which is not selected.
- Installed KWin `6.8.2` scripts provide concrete examples of the KWin-side API: `minimizeall/contents/code/main.js` calls `workspace.windowList()`, reads `workspace.activeWindow`, and assigns `workspace.activeWindow`; `synchronizeskipswitcher/contents/code/main.js` subscribes to `workspace.windowAdded` and window property signals. D-Bus introspection of `org.kde.KWin.Scripting` exposes `loadScript`, `loadDeclarativeScript`, and `unloadScript`. This is a KWin script extension surface, not a generic client protocol.
- Quickshell `0.3.2`'s installed QML module tree exposes `Quickshell.DBusMenu` but no generic D-Bus service/object export type was found. A script-to-shell bridge and its trust boundary remain unsolved. KWin `v6.8.2`'s `org.kde.KWin.Scripting` creates an individually addressable object at `/Scripting/Script<ID>` with `run`/`stop`; use the ID returned by `loadScript`, never guess `Script0` or call global `start()`. The read-only script probe loaded as ID `1`, ran via `/Scripting/Script1`, and unloaded successfully (`isScriptLoaded`: true then false), but its count-only `console.info` output was not visible in the queried journal, so window access/data is not yet independently confirmed. An earlier attempt invoked `/Scripting/Script0` instead of ID `1`; this may have run a pre-existing script. No script was stopped or unloaded except the uniquely named probe, and no persistent settings were changed. Avoid repeating the wrong-path call.
- The flake declares `pkgs.kdePackages.kwayland` (evaluated version `6.8.2`) plus Qt, CMake/pkg-config and Wayland dependencies for the isolated C++ helper at `poc/kwin-backend-probe/`. Its `--watch` NDJSON contains window IDs/titles/app IDs/state/geometry/desktop IDs/AppMenu addresses and workspace state; treat raw output as sensitive. The new `--menu-watch` mode retrieves the D-BusMenu tree and accepts only validated event IDs/actions from the isolated `poc/global-menu/` local pipe; never expose its raw output because it contains menu labels. The helper requires `QGuiApplication` for KWayland window-icon deserialization and a brief event-loop drain before clean one-shot teardown. In Plasma/KWin `6.8.2`, the helper built and ran with protocol v21, six windows, active-window presence, workspace read available and the AppMenu registration global advertised. With native-Wayland KWrite active (`org.kde.kwrite`), the AppMenu address eventually appeared and `--menu-check` retrieved `GetLayout` with 8 root items. The active process maps Qt's `libqwayland.so`, not `libqxcb.so`; Xwayland remains untested. The menu tree parses to 8 root / 132 total / 96 labeled items via sanitized check. Bounded Quickshell runs loaded the new renderer; user visual verification and runtime D-BusMenu Event/leaf activation remain pending. These observations are session-specific, not a public/stable client API or production backend.
- Per-window previews currently depend on a Hyprland capture path. KWin desktop screencasting does not prove per-window screencopy compatibility.

No production KWin backend or abstraction has been implemented. The isolated window-status fixture is diagnostic-only; the separate Global Menu renderer POC is under `poc/global-menu/` and neither is wired into MacShell QML. Live introspection of `org.kde.KWin` exposes `activeOutputName`, `currentDesktop`, `getWindowInfo(QString)`, `queryWindowInfo()` and `supportInformation()`, but no window-list or active-window property on that object. Local `supportInformation()` confirms KWin `6.8.2`, Wayland operation and Breeze decoration.

## Work requested

Research and propose a KWin adapter boundary that reports actual capability and access status for each operation:

- active window and window enumeration (title, app ID, icon, geometry and state);
- activation/focus, minimize/maximize/fullscreen/close and state updates;
- workspace enumeration/current workspace/switch/move window;
- output enumeration/geometry/scale/hotplug;
- optional window preview/capture;
- lock, logout, reboot, suspend/resume integration.

Compare supported KWin approaches: public Wayland protocols, KDE D-Bus APIs, KWin scripting and an isolated helper/plugin. For each method state: public/stable vs desktop-only/private, permission model, Xwayland/native Wayland coverage, required packages and version coupling. Investigate actual latest upstream sources and include source links/revisions. Do not invent APIs.

Recommend a minimal QML-facing interface that can report unsupported operations explicitly. Keep presentation widgets decoupled and avoid changing `MacBar.qml`/`MacDock.qml` until the interface and proof points are reviewed. Prefer a narrow helper boundary if KWin's trusted desktop-side APIs cannot safely be called from Quickshell.

## Constraints and deliverables

- KWin must remain compositor; Klassy remains the decoration provider. Never implement a competing application decoration.
- Do not add Hyprland replacement under KWin by shelling out to `hyprctl`; do not assume Wayland clients may enumerate/focus arbitrary windows.
- Avoid undocumented/private interfaces unless a clearly documented compelling reason, compatibility guard and failure behavior are provided.
- Keep screen capture opt-in to protect laptop battery and avoid unnecessary NVIDIA wakeups.
- Preserve native KDE lock/session services until alternatives are proven secure.
- Provide a capability matrix, API-source links, trust/security assessment, suggested interface and staged implementation plan. Do not modify source files in this research lane.
