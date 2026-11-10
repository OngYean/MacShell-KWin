// KWinBackend — MacShell's compositor backend for KDE Plasma (KWin), driven by the macshell-kwin-bridge helper.
//
// KWin does not offer the generic protocols Quickshell's own window list and capture use (wlr-foreign-toplevel,
// wlr-screencopy / ext-image-copy-capture), so everything window related comes from the bridge (kwin-bridge/README.md):
// it streams window / workspace / keyboard / global-menu state as JSON lines and takes validated commands on stdin.
// Only the Compositor facade uses this file; see Compositor.qml for the meaning of each member.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property bool active: false
    // import the active app's real menu (also makes kded run the AppMenu registrar, so apps export their menus at all)
    property bool globalMenu: true

    property string status: active ? "starting" : "inactive"
    property bool ready: false
    property bool windowManagement: false
    property bool globalMenuAvailable: false
    // the bridge can take a still picture of a window (KWin's screenshot interface), for the Dock's minimized windows
    property bool snapshotsAvailable: false
    property bool snapshotsWanted: false          // set through the facade by the Dock
    property var snapshotAsked: ({})              // window id → asked for this spell of being minimized (plain bookkeeping)
    property int minimizedRev: 0                  // counts up whenever a window is minimized or restored

    // ── raw bridge state ──
    property var windowList: []                 // bridge window objects (id, appId, title, pid, active, minimized, ..., x, y, width, height, desktops)
    property string activeId: ""
    property var desktops: []                   // sorted by position: { id (KWin uuid), name, position }
    property string currentDesktop: ""
    property var layouts: []
    property int layoutIndex: -1
    property var appMenu: ({ status: "none", windowId: "", appId: "", revision: 0, items: [] })
    // coexist (default): plasmashell keeps its notifications / OSD / desktop; MacShell serves notifications only when nobody
    // else does (notificationsUnserved). replace: plasmashell was stopped for this session (macshell-session replace) and
    // MacShell takes over notifications. Quickshell's notification server is process-wide and keeps re-claiming its D-Bus
    // name, so once MacShell serves them a plasmashell (re)started later shows none: MacShell's bell has them instead.
    readonly property bool replaceMode: String(Quickshell.env("MACSHELL_KDE_MODE") || "coexist") === "replace"
    property bool sessionKnown: false            // the bridge has reported who owns the desktop services
    property bool plasmaShellRunning: false
    property string notificationsOwner: "none"   // none | self | bridge | other (see the bridge's "session" message)
    property string menuViewOwner: "none"

    readonly property var caps: ({
        windows: root.windowManagement, activate: root.windowManagement, close: root.windowManagement,
        minimize: root.windowManagement, maximize: root.windowManagement, fullscreen: root.windowManagement,
        workspaces: root.desktops.length > 0, moveToWorkspace: root.windowManagement && root.desktops.length > 0,
        keyboardLayouts: root.layouts.length > 0, globalMenu: root.globalMenuAvailable, backgroundEffect: true,
        sessionActions: true, systemSettings: true,
        // KWin's minimize effects (Magic Lamp) can be told where each window's Dock icon is (setIconTargets)
        minimizeTarget: root.windowManagement && root.iconScreens.length > 0,
        windowSnapshot: root.windowManagement && root.snapshotsAvailable,
        // KWin offers no capture protocol to ordinary clients, draws (Klassy) decorations itself and has no layer rules
        windowCapture: false, screenCapture: false, drawDecorations: false, windowRules: false, layerBlurRules: false,
        windowLayout: false, sendShortcut: false, colorPicker: false, nightShift: false, monitorConfig: false, inputConfig: false,
        // never a second daemon next to another owner of org.freedesktop.Notifications (plasmashell's tray, usually; see replaceMode)
        notificationServer: root.sessionKnown && root.notificationsOwner !== "other"
                            && ((root.replaceMode && !root.plasmaShellRunning) || root.notificationsUnserved)
    })
    // coexist: plasmashell serves notifications only from a system tray. Without one nobody does, and every notification is
    // lost, so MacShell takes the name once it has stayed free for a while (the grace lets a tray claim it first at login).
    // Plasma's notification server can't replace Quickshell's (which disallows replacement), so the two never alternate.
    property bool notificationsUnserved: false
    Timer {
        interval: 15000
        running: root.sessionKnown && root.notificationsOwner === "none" && !root.notificationsUnserved
        onTriggered: root.notificationsUnserved = true
    }
    onNotificationsOwnerChanged: if (notificationsOwner === "other") notificationsUnserved = false

    // ── Quickshell-Toplevel-like objects, one per window, kept stable (the switcher and Dock keep references) ──
    property var toplevels: []
    property var byId: ({})                     // plain bookkeeping, mutated in place (not bound to)
    readonly property var activeToplevel: {
        for (var i = 0; i < toplevels.length; i++) if (toplevels[i].address === activeId) return toplevels[i];
        return null;
    }
    Component {
        id: adapterComp
        QtObject {
            property var backend: null
            property string address: ""
            property string appId: ""
            property string title: ""
            property bool activated: false
            property bool minimized: false
            property bool maximized: false
            property bool fullscreen: false
            property string snapshot: ""       // a picture of the window while it is minimized (data: URL), "" = none
            property var info: ({})
            function activate() { backend.send({ cmd: "activate", id: address }); }
            function close() { backend.send({ cmd: "close", id: address }); }
            function setMinimized(on) { backend.send({ cmd: on ? "minimize" : "unminimize", id: address }); }
            function setMaximized(on) { if (on !== maximized) backend.send({ cmd: "toggleMaximize", id: address }); }
            function setFullscreen(on) { if (on !== fullscreen) backend.send({ cmd: "toggleFullscreen", id: address }); }
        }
    }
    function syncToplevels() {
        var seen = {}, next = [], i, w, a, map = byId, changed = false, minChanged = false;
        for (i = 0; i < windowList.length; i++) {
            w = windowList[i];
            if (w.skipTaskbar) continue;           // Plasma's desktop / panels / OSDs, as Plasma's own task manager filters them
            seen[w.id] = true;
            a = map[w.id];
            if (!a) { a = adapterComp.createObject(root, { backend: root, address: w.id }); map[w.id] = a; changed = true; }
            a.appId = w.appId || w.resourceName || "";
            a.title = w.title || "";
            a.activated = w.id === activeId;
            if (a.minimized !== (w.minimized === true)) minChanged = true;
            a.minimized = w.minimized === true;
            // one picture per spell of being minimized, asked for when it starts; forgotten when the window is back
            if (!a.minimized) { a.snapshot = ""; delete snapshotAsked[w.id]; }
            else if (snapshotsWanted && snapshotsAvailable && !snapshotAsked[w.id]) { snapshotAsked[w.id] = true; send({ cmd: "snapshot", id: w.id }); }
            a.maximized = w.maximized === true;
            a.fullscreen = w.fullscreen === true;
            a.info = w;
        }
        // keep the old order (creation order, like ToplevelManager), new windows at the end
        for (i = 0; i < toplevels.length; i++) if (seen[toplevels[i].address]) next.push(toplevels[i]);
        for (var id in seen) if (next.indexOf(map[id]) < 0) next.push(map[id]);
        for (var k in map) if (!seen[k]) { map[k].destroy(); delete map[k]; delete snapshotAsked[k]; changed = true; }
        if (minChanged) minimizedRev++;
        if (changed || next.length !== toplevels.length) toplevels = next;
        else for (i = 0; i < next.length; i++) if (next[i] !== toplevels[i]) { toplevels = next; break; }
    }

    // ── geometry snapshots in the shape the glass / smart-hide code already reads (hyprctl -j clients / monitors) ──
    function desktopNumber(uuid) {
        for (var i = 0; i < desktops.length; i++) if (desktops[i].id === uuid) return i + 1;
        return 0;
    }
    readonly property int activeWorkspaceId: desktopNumber(currentDesktop)
    readonly property var workspaceIds: {
        var ids = [];
        for (var i = 0; i < desktops.length; i++) ids.push(i + 1);
        return ids.length > 0 ? ids : [1];
    }
    function screenIndexAt(x, y) {
        var s = Quickshell.screens;
        for (var i = 0; i < s.length; i++) if (x >= s[i].x && x < s[i].x + s[i].width && y >= s[i].y && y < s[i].y + s[i].height) return i;
        return s.length > 0 ? 0 : -1;
    }
    function clientFor(w) {
        var onAll = w.onAllDesktops === true, ws = onAll ? activeWorkspaceId : (w.desktops && w.desktops.length > 0 ? desktopNumber(w.desktops[0]) : 0);
        var mon = screenIndexAt(w.x + w.width / 2, w.y + w.height / 2);
        if (w.desktops && !onAll && w.desktops.indexOf(currentDesktop) >= 0) ws = activeWorkspaceId;   // shown here now
        return {
            address: w.id, "class": w.appId || w.resourceName || "", title: w.title || "", pid: w.pid || 0,
            at: [w.x, w.y], size: [w.width, w.height], workspace: { id: ws, name: "" + ws }, monitor: mon,
            // a KWin window "tiles" the screen (in Hyprland's sense) only when maximized or fullscreen
            floating: !(w.maximized || w.fullscreen), fullscreen: w.fullscreen ? 2 : (w.maximized ? 1 : 0),
            pinned: onAll, mapped: true, hidden: w.minimized === true
        };
    }
    readonly property var clients: {
        var out = [];
        for (var i = 0; i < windowList.length; i++) if (!windowList[i].skipTaskbar) out.push(clientFor(windowList[i]));
        return out;
    }
    readonly property var activeWindow: {
        for (var i = 0; i < windowList.length; i++) if (windowList[i].id === activeId) return clientFor(windowList[i]);
        return null;
    }
    // KWin activates a layer surface that takes the keyboard (Spotlight, the switcher), so for a moment no client window
    // is active: keep the screen of the last active window then, instead of falling back to the first screen
    property string lastFocusedScreen: ""
    onActiveWindowChanged: if (activeWindow && activeWindow.monitor >= 0 && activeWindow.monitor < Quickshell.screens.length)
                               lastFocusedScreen = Quickshell.screens[activeWindow.monitor].name
    readonly property string focusedScreenName: {
        var s = Quickshell.screens, w = activeWindow;
        if (s.length === 0) return "";
        if (w && w.monitor >= 0) return s[w.monitor].name;
        for (var i = 0; i < s.length; i++) if (s[i].name === lastFocusedScreen) return lastFocusedScreen;
        return s[0].name;
    }
    readonly property var monitors: {
        var s = Quickshell.screens, out = [];
        // as hyprctl reports them: logical position, mode size in physical pixels, scale
        for (var i = 0; i < s.length; i++)
            out.push({ id: i, name: s[i].name, x: s[i].x, y: s[i].y, scale: s[i].devicePixelRatio,
                       width: Math.round(s[i].width * s[i].devicePixelRatio), height: Math.round(s[i].height * s[i].devicePixelRatio),
                       activeWorkspace: { id: activeWorkspaceId }, specialWorkspace: { id: 0 }, focused: s[i].name === focusedScreenName });
        return out;
    }
    function workspaceOccupied(n) {
        var d = n >= 1 && n <= desktops.length ? desktops[n - 1].id : "";
        for (var i = 0; i < windowList.length; i++) {
            var w = windowList[i];
            if (!w.skipTaskbar && (w.onAllDesktops || (w.desktops && w.desktops.indexOf(d) >= 0))) return true;
        }
        return false;
    }

    // ── commands ──
    function send(obj) { if (bridge.running) bridge.write(JSON.stringify(obj) + "\n"); }
    function windowCmd(cmd, addr) { var id = addr && addr !== "" ? String(addr) : activeId; if (id !== "") send({ cmd: cmd, id: id }); }
    function switchWorkspace(sel) {
        var s = String(sel), n = desktops.length, cur = activeWorkspaceId, target = -1;
        if (n === 0) return;
        var rel = /^[er]?([+-]\d+)$/.exec(s);
        if (rel) target = ((cur - 1 + Number(rel[1])) % n + n) % n + 1;
        else if (/^\d+$/.test(s)) target = Number(s);
        if (target >= 1 && target <= n) send({ cmd: "setDesktop", desktop: desktops[target - 1].id });
    }
    function moveWindowToWorkspace(addr, n) {
        var id = addr && addr !== "" ? String(addr) : activeId;
        if (id !== "" && n >= 1 && n <= desktops.length) send({ cmd: "moveToDesktop", id: id, desktop: desktops[n - 1].id });
    }
    function activateWindow(addr) { windowCmd("activate", addr); }
    function closeWindow(addr) { windowCmd("close", addr); }
    function minimizeWindow(addr) { windowCmd("minimize", addr); }
    function toggleMaximize(addr) { windowCmd("toggleMaximize", addr); }
    function toggleFullscreen(addr) { windowCmd("toggleFullscreen", addr); }
    function refreshActiveWindow() { }                            // pushed by the bridge, nothing to ask for
    function workspaceForScreen(screen) { return activeWorkspaceId; }   // KWin virtual desktops span every output
    readonly property var keyboardLayouts: layouts.map(function (l) { return { code: l.short || "", name: l.name || l.display || l.short || "" }; })
    readonly property int keyboardIndex: layoutIndex
    function setKeyboardLayout(i) { send({ cmd: "setKeyboardLayout", index: i }); }

    // ── session: KDE's own services, so the session is saved and KDE's lock screen (not MacLock) is used ──
    // --print-reply keeps dbus-send on the bus until the call is answered. org.kde.Shutdown is started on demand, and
    // dbus-daemon drops a call queued for a starting service once its sender has disconnected (bus/activation.c): without
    // it Log Out, Restart and Shut Down did nothing, while Lock worked because KWin's locker is always running.
    function dbusSend(dest, path, method) {
        Quickshell.execDetached(["dbus-send", "--session", "--print-reply", "--type=method_call", "--dest=" + dest, path, dest + "." + method]);
    }
    function lock() { dbusSend("org.freedesktop.ScreenSaver", "/ScreenSaver", "Lock"); }
    function sleep() { Quickshell.execDetached(["systemctl", "suspend"]); }   // logind; KDE's screen locker locks on suspend per its settings
    function logout() { dbusSend("org.kde.Shutdown", "/Shutdown", "logout"); }
    function reboot() { dbusSend("org.kde.Shutdown", "/Shutdown", "logoutAndReboot"); }
    function shutdown() { dbusSend("org.kde.Shutdown", "/Shutdown", "logoutAndShutdown"); }
    // input / display / Night Light settings belong to KDE: open its settings module instead of writing kwinrc
    function openSystemSettings(module) { Quickshell.execDetached(module ? ["systemsettings", module] : ["systemsettings"]); }
    function showDesktop(on) { send({ cmd: "showDesktop", on: on === true }); }
    // windowId: the window whose menu was opened (the bridge drops events for any other), default the current one
    function menuEvent(itemId, event, windowId) { send({ cmd: "menuEvent", windowId: windowId !== undefined ? windowId : appMenu.windowId, id: itemId, event: event }); }
    function menuAboutToShow(itemId, windowId) { send({ cmd: "menuAboutToShow", windowId: windowId !== undefined ? windowId : appMenu.windowId, id: itemId }); }

    // ── minimize targets: where the Dock shows each window, so Magic Lamp animates into it instead of towards the pointer ──
    property var iconScreens: []                // screens the bridge has an anchor surface on ("iconAnchors")
    property var iconWanted: ({})               // address → { screen, x, y, width, height }: the screen's own logical pixels
    property var iconSent: ({})                 // address → what the bridge has now (JSON); a new bridge has nothing
    function setIconTargets(map) { iconWanted = map || {}; syncIconTargets(); }
    // only changes are sent, and only for windows the bridge already knows (it drops the rest), so this also runs on "windows"
    function syncIconTargets() {
        if (!ready) return;
        var sent = iconSent, next = {}, a, t, j;
        for (a in iconWanted) {
            if (!byId[a]) continue;
            t = iconWanted[a];
            j = JSON.stringify(t);
            next[a] = j;
            if (sent[a] !== j) send({ cmd: "iconGeometry", id: a, screen: t.screen, x: t.x, y: t.y, width: t.width, height: t.height });
        }
        for (a in sent) if (next[a] === undefined && byId[a]) send({ cmd: "iconGeometry", id: a, screen: "" });
        iconSent = next;
    }

    // ── the bridge process ──
    function consume(line) {
        var m;
        try { m = JSON.parse(line); } catch (err) { return; }
        if (m.type === "hello") {
            ready = true;
            restartDelay = 1000;
            windowManagement = m.windowManagement === "available";
            globalMenuAvailable = m.globalMenu === true;
            snapshotsAvailable = m.snapshots === true;
            status = windowManagement ? "ok" : "window-management-unsupported";
        } else if (m.type === "windows") {
            activeId = m.activeId || "";
            windowList = m.windows || [];
            syncToplevels();
            syncIconTargets();
        } else if (m.type === "snapshot") {
            var sa = byId[m.id];
            if (sa && sa.minimized && typeof m.url === "string" && m.url.indexOf("data:image/") === 0) sa.snapshot = m.url;
        } else if (m.type === "iconAnchors") {
            iconScreens = m.screens || [];
        } else if (m.type === "workspaces") {
            var d = (m.desktops || []).slice();
            d.sort(function (a, b) { return a.position - b.position; });
            desktops = m.available ? d : [];
            currentDesktop = m.current || "";
        } else if (m.type === "keyboard") {
            layouts = m.layouts || [];
            layoutIndex = typeof m.current === "number" ? m.current : -1;
        } else if (m.type === "menu") {
            appMenu = { status: m.status || "none", windowId: m.windowId || "", appId: m.appId || "", revision: m.revision || 0, items: m.items || [] };
        } else if (m.type === "session") {
            plasmaShellRunning = m.plasmashell === true;
            sessionKnown = true;
            notificationsOwner = m.notifications || "none";
            menuViewOwner = m.menuView || "none";
        }
    }
    property int restartDelay: 1000
    Process {
        id: bridge
        // MACSHELL_KWIN_BRIDGE: another bridge, e.g. kwin-bridge/fake-bridge.py to exercise this UI without KWin
        command: [String(Quickshell.env("MACSHELL_KWIN_BRIDGE") || "macshell-kwin-bridge")].concat(root.globalMenu ? ["--global-menu"] : [])
        running: root.active
        stdinEnabled: true
        stdout: SplitParser { splitMarker: "\n"; onRead: data => root.consume(data) }
        // status codes only (never titles or labels); without a reader Quickshell closes the pipe and they are lost
        stderr: SplitParser { splitMarker: "\n"; onRead: data => console.warn("[kwin-bridge]", data) }
        onExited: (exitCode, exitStatus) => {
            root.ready = false;
            root.status = "bridge-exited-" + exitCode;
            root.windowList = []; root.activeId = ""; root.syncToplevels();
            root.appMenu = { status: "none", windowId: "", appId: "", revision: 0, items: [] };
            root.iconScreens = []; root.iconSent = {};    // the next bridge starts with no anchors and no targets
            root.snapshotsAvailable = false; root.snapshotAsked = {};
            if (root.active) restartT.restart();          // KWin restarted or the bridge crashed: come back, with backoff
        }
    }
    Timer {
        id: restartT
        interval: root.restartDelay
        onTriggered: { root.restartDelay = Math.min(30000, root.restartDelay * 2); if (root.active) bridge.running = true; }
    }
    // switched on with windows already minimized: ask for their pictures now
    onSnapshotsWantedChanged: if (snapshotsWanted) syncToplevels()
    // the flag is a bridge argument: stopping it lets onExited start it again with the new command
    onGlobalMenuChanged: if (bridge.running) bridge.running = false
    // a missing bridge binary never says hello
    Timer { interval: 6000; running: root.active && !root.ready; onTriggered: if (!root.ready) root.status = "bridge-unavailable" }
}
