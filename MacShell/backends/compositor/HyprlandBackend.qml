// HyprlandBackend — MacShell's original compositor integration (Hyprland 0.55+, Lua dispatch), behind the Compositor facade.
// The dispatch strings are the ones MacBar / WindowBar / WindowDecor sent before the facade existed; see Compositor.qml.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: root

    property bool active: false
    readonly property string status: active ? "ok" : "inactive"
    readonly property bool ready: active

    readonly property var caps: ({
        windows: true, activate: true, close: true, minimize: true, maximize: true, fullscreen: true,
        workspaces: true, moveToWorkspace: true, keyboardLayouts: false, globalMenu: false, backgroundEffect: false,
        sessionActions: true, systemSettings: false,
        windowCapture: true, screenCapture: true, drawDecorations: true, windowRules: true, layerBlurRules: true,
        windowLayout: true, sendShortcut: true, colorPicker: true, nightShift: true, monitorConfig: true, inputConfig: true,
        notificationServer: true, minimizeTarget: false
    })

    readonly property var toplevels: active ? ToplevelManager.toplevels.values : []
    readonly property var activeToplevel: active ? ToplevelManager.activeToplevel : null

    // Hyprland's view of the focused window (floating / fullscreen / pinned / pid ...), refreshed on demand
    property var activeWindow: null
    function refreshActiveWindow() { if (active && !awProc.running) awProc.running = true; }
    Process {
        id: awProc
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                var o = null;
                try { o = JSON.parse(text); } catch (err) { o = null; }
                root.activeWindow = (o && o.address) ? o : null;
            }
        }
    }

    // window + monitor geometry for Hyprland stays in shell.qml (its IPC fast path / hyprctl pollers); nothing here
    readonly property var clients: []
    readonly property var monitors: []

    readonly property string focusedScreenName: active && Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    // ── workspaces: the ones Hyprland really has (0.55+ creates and destroys them on demand) ──
    Connections {
        target: root.active ? Hyprland : null
        function onRawEvent(event) {
            var n = event.name;
            if (n === "createworkspacev2" || n === "destroyworkspacev2" || n === "workspacev2" || n === "moveworkspacev2" || n === "renameworkspace")
                Hyprland.refreshWorkspaces();
        }
    }
    function workspaceList(minimum) {
        var ids = [], vals = active ? Hyprland.workspaces.values : [];
        for (var i = 1; i <= minimum; i++) ids.push(i);
        for (var j = 0; j < vals.length; j++) {
            var id = vals[j].id;
            if (id > 0 && ids.indexOf(id) < 0) ids.push(id);
        }
        var fw = active ? Hyprland.focusedWorkspace : null;
        if (fw && fw.id > 0 && ids.indexOf(fw.id) < 0) ids.push(fw.id);
        if (ids.length === 0) ids.push(1);                    // never an empty counter
        ids.sort(function (a, b) { return a - b; });
        return ids;
    }
    readonly property var workspaceIds: workspaceList(0)
    readonly property int activeWorkspaceId: active && Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    function workspaceForScreen(screen) {
        var mon = active && screen ? Hyprland.monitorFor(screen) : null;
        return mon && mon.activeWorkspace ? mon.activeWorkspace.id : activeWorkspaceId;
    }
    function workspaceOccupied(id) {
        var vals = active ? Hyprland.workspaces.values : [];
        for (var i = 0; i < vals.length; i++) if (vals[i].id === id) return (vals[i].toplevels ? vals[i].toplevels.values.length : 0) > 0;
        return false;
    }
    function switchWorkspace(sel) {      // Hyprland 0.55+ (Lua) workspace switch
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + sel + "\" })"]);
    }

    // ── windows: addr is a Hyprland address ("0x…" or bare hex); "" = the focused window ──
    function sel(addr) {
        if (!addr) return "";
        var a = String(addr);
        return 'window = "address:' + (a.indexOf("0x") === 0 ? a : "0x" + a) + '"';
    }
    function dispatch(fn, args, addr) {
        var s = sel(addr), all = [args, s].filter(function (x) { return x !== ""; }).join(", ");
        Hyprland.dispatch(all === "" ? fn + "()" : fn + "({ " + all + " })");
    }
    function activateWindow(addr) { Hyprland.dispatch('hl.dsp.focus({ ' + sel(addr) + ' })'); }
    function closeWindow(addr) { dispatch("hl.dsp.window.close", "", addr); }
    function minimizeWindow(addr) { dispatch("hl.dsp.window.move", 'workspace = "special:minimized", follow = false', addr); }
    function toggleMaximize(addr) { dispatch("hl.dsp.window.fullscreen", 'mode = "maximized", action = "toggle"', addr); }
    function toggleFullscreen(addr) { dispatch("hl.dsp.window.fullscreen", 'mode = "fullscreen", action = "toggle"', addr); }
    function moveWindowToWorkspace(addr, n) { dispatch("hl.dsp.window.move", 'workspace = "' + n + '", follow = false', addr); }
    function showDesktop(on) { }

    // ── session: MacLock is the lock screen on Hyprland; UWSM sessions are stopped through uwsm so they end cleanly ──
    function sh(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }
    function lock() { sh('sh ~/.config/quickshell/MacLock/lock-via-ipc.sh'); }
    function sleep() { sh('sh ~/.config/quickshell/MacLock/lock-via-ipc.sh; sleep 0.5; systemctl suspend'); }
    function logout() {
        sh('if command -v uwsm >/dev/null 2>&1 && uwsm check is-active >/dev/null 2>&1; then uwsm stop; '
           + 'else hyprctl dispatch "hl.dsp.exit()" || hyprctl dispatch exit; fi');
    }
    function reboot() { sh("systemctl reboot"); }
    function shutdown() { sh("systemctl poweroff"); }

    // KDE-only members, inert here
    readonly property var keyboardLayouts: []
    readonly property int keyboardIndex: -1
    function setKeyboardLayout(i) { }
    readonly property var appMenu: ({ status: "unsupported", windowId: "", appId: "", revision: 0, items: [] })
    function menuEvent(itemId, event, windowId) { }
    function menuAboutToShow(itemId, windowId) { }
    function setIconTargets(map) { }                 // only KWin's minimize effects take a target
    readonly property bool plasmaShellRunning: false
    readonly property string notificationsOwner: "none"
    function openSystemSettings(module) { }
}
