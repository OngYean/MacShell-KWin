# Independent task: KWin compositor/backend assessment

This brief is self-contained. Read the repository `AGENTS.md` first; it is the project authority. The goal is a stable UI/backend boundary, not an early broad rewrite of the MacShell QML.

## Context and current state

MacShell in this workspace is still upstream-derived and Hyprland-dependent. It is intended for latest upstream Plasma 6 Wayland with KWin, while retaining Klassy/KDecoration3 and KDE services. The user is currently in Hyprland and will enter Plasma after enabling it in their host config; they will notify the project then. Do not alter host configuration, switch sessions, install software, run installers, or disable KDE components.

Current source audit:

- `MacShell/shell.qml` imports `Quickshell.Hyprland`, polls `hyprctl` JSON/IPC and derives monitor/client state from Hyprland.
- `MacShell/MacBar.qml` sends Hyprland Lua/CLI commands for window/workspace/input/session operations.
- `MacShell/MacDock.qml` uses Quickshell `ToplevelManager`, current-source implementation backed by wlroots foreign-toplevel management, and Hyprland-specific window rules/actions.
- KWin current source did not advertise wlr foreign-toplevel management. Do not assume this Quickshell manager will enumerate KWin windows.
- KWin's Plasma Window Management protocol contains rich window/workspace information and requests, but its XML says regular clients must not use it (desktop-environment implementation detail); current KWin source also restricts sandboxed clients. Treat it as an access/security risk, not a public contract.
- KWin current source includes layer-shell v1 support. A basic Quickshell panel is plausible but untested in the user's target session.
- Per-window previews currently depend on a Hyprland capture path. KWin desktop screencasting does not prove per-window screencopy compatibility.

No KWin backend or abstraction has been implemented. The intended Nix flake only packages existing Hyprland QML and does not change that.

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
