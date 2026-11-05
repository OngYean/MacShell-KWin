// Compositor — the one place MacShell's UI talks to the compositor. shell.qml creates it and hands it out as hub.compositor.
//
// Backend: MACSHELL_COMPOSITOR=hyprland|kwin|none forces one; otherwise Hyprland when HYPRLAND_INSTANCE_SIGNATURE is set,
// KWin when XDG_CURRENT_DESKTOP names KDE, else "none" (generic Wayland: window features report unsupported).
//
// Windows are identified by an opaque `address` string (Hyprland: hex address, KWin: window uuid); "" means the focused
// window. Workspaces are numbers (Hyprland: its workspace ids, KWin: virtual desktop position, 1-based).
// Before using a feature that only one compositor has, check can("<feature>"); the keys are listed in `caps` of each backend:
//   windows activate close minimize maximize fullscreen workspaces moveToWorkspace keyboardLayouts globalMenu sessionActions
//   systemSettings backgroundEffect windowCapture screenCapture drawDecorations windowRules layerBlurRules windowLayout
//   sendShortcut colorPicker nightShift monitorConfig inputConfig notificationServer
import QtQuick
import Quickshell

Scope {
    id: root

    readonly property string requested: String(Quickshell.env("MACSHELL_COMPOSITOR") || "auto").toLowerCase()
    readonly property string name: (requested === "hyprland" || requested === "kwin" || requested === "none") ? requested
        : (String(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") !== "" ? "hyprland"
        : (/(^|:)KDE(:|$)/i.test(String(Quickshell.env("XDG_CURRENT_DESKTOP") || "")) ? "kwin" : "none"))
    readonly property bool isHyprland: name === "hyprland"
    readonly property bool isKWin: name === "kwin"
    readonly property var backend: isHyprland ? hyprland : (isKWin ? kwin : null)

    // set by MacBar: import the active app's real menu (KWin)
    property bool globalMenuWanted: true

    HyprlandBackend { id: hyprland; active: root.isHyprland }
    KWinBackend {
        id: kwin
        active: root.isKWin
        globalMenu: root.globalMenuWanted && String(Quickshell.env("MACSHELL_GLOBAL_MENU") || "1") !== "0"
    }

    readonly property string status: backend ? backend.status : "unsupported"
    readonly property bool ready: backend ? backend.ready : false
    readonly property var caps: backend ? backend.caps : ({})
    function can(feature) { return caps[feature] === true; }

    // ── windows ──
    // Quickshell-Toplevel-like objects: appId, title, activated, minimized, maximized, fullscreen, activate(), close()
    readonly property var toplevels: backend ? backend.toplevels : []
    readonly property var activeToplevel: backend ? backend.activeToplevel : null
    // the focused window as `hyprctl -j activewindow` describes it: address, class, title, pid, at, size, workspace{id,name},
    // floating, fullscreen (0 / 1 maximized / 2 fullscreen), pinned
    readonly property var activeWindow: backend ? backend.activeWindow : null
    function refreshActiveWindow() { if (backend) backend.refreshActiveWindow(); }
    // KWin only (Hyprland's live geometry comes from shell.qml's own pollers): `hyprctl -j clients` / `monitors` shaped
    readonly property var clients: backend ? backend.clients : []
    readonly property var monitors: backend ? backend.monitors : []
    readonly property string focusedScreenName: backend ? backend.focusedScreenName : ""

    function activateWindow(addr) { if (backend) backend.activateWindow(addr); }
    function closeWindow(addr) { if (backend) backend.closeWindow(addr); }
    function minimizeWindow(addr) { if (backend) backend.minimizeWindow(addr); }
    function toggleMaximize(addr) { if (backend) backend.toggleMaximize(addr); }
    function toggleFullscreen(addr) { if (backend) backend.toggleFullscreen(addr); }
    function moveWindowToWorkspace(addr, n) { if (backend) backend.moveWindowToWorkspace(addr, n); }
    function showDesktop(on) { if (backend) backend.showDesktop(on); }

    // ── workspaces ──
    readonly property var workspaceIds: backend ? backend.workspaceIds : [1]
    readonly property int activeWorkspaceId: backend ? backend.activeWorkspaceId : -1
    function workspaceForScreen(screen) { return backend ? backend.workspaceForScreen(screen) : -1; }
    function workspaceOccupied(n) { return backend ? backend.workspaceOccupied(n) : false; }
    // n, "n", or relative "+1" / "-1" (also Hyprland's "e+1" / "r-1")
    function switchWorkspace(sel) { if (backend) backend.switchWorkspace(sel); }

    // ── keyboard layouts (KWin; MacBar reads Hyprland's itself) ──
    readonly property var keyboardLayouts: backend ? backend.keyboardLayouts : []      // { code, name }
    readonly property int keyboardIndex: backend ? backend.keyboardIndex : -1
    function setKeyboardLayout(i) { if (backend) backend.setKeyboardLayout(i); }

    // ── global menu (KWin): the active window's exported com.canonical.dbusmenu tree ──
    // { status: ok | loading | none | error | unsupported, windowId, appId, revision, items: [{ id, label, enabled, visible,
    //   separator, submenu, toggle: "" | checkmark | radio, toggleState, icon, shortcut: [["Control","S"]], children }] }
    readonly property var appMenu: backend ? backend.appMenu : ({ status: "unsupported", windowId: "", appId: "", revision: 0, items: [] })
    // event: clicked | opened | closed; windowId: the appMenu.windowId the menu was opened for (events for another are dropped)
    function menuEvent(itemId, event, windowId) { if (backend) backend.menuEvent(itemId, event, windowId); }
    function menuAboutToShow(itemId, windowId) { if (backend) backend.menuAboutToShow(itemId, windowId); }

    // ── session ──
    function lock() { if (backend) backend.lock(); }
    function sleep() { if (backend) backend.sleep(); }
    function logout() { if (backend) backend.logout(); }
    function reboot() { if (backend) backend.reboot(); }
    function shutdown() { if (backend) backend.shutdown(); }
    function openSystemSettings(module) { if (backend) backend.openSystemSettings(module); }
    // ── layer surfaces ──
    // KWin reads a layer surface's namespace as its window type (layershellv1window.cpp, scopeToType). Any name but its own is a
    // Normal application window, which force-blur effects blur edge to edge (MacShell's surfaces span the screen) and which
    // ends "show desktop". On KWin every MacShell surface is a "dock"; Hyprland keeps the names its layer rules match.
    function layerNamespace(name) { return isKWin ? "dock" : name; }

    // KDE: who already provides desktop services (so MacShell never starts a duplicate)
    readonly property bool plasmaShellRunning: backend ? backend.plasmaShellRunning : false
    // KDE without plasmashell (macshell-session replace): nobody draws the wallpaper or ends the login splash (Wallpaper.qml)
    readonly property bool desktopUnserved: isKWin && backend.sessionKnown && !backend.plasmaShellRunning
    readonly property string notificationsOwner: backend ? backend.notificationsOwner : "none"
}
