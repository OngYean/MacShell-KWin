// Wallpaper — stands in for plasmashell's desktop on KDE Plasma while plasmashell is not running (macshell-session replace).
//
// plasmashell normally does two things here: it draws the wallpaper, and it tells the login splash (KSplash) that the
// desktop is up. Without it the screen behind the windows stays empty and the splash only closes on its 30 s timeout.
// Inactive in every other case (plasmashell running, Hyprland, other compositors): no window, no process.
//
// The picture is the one the Liquid Glass refracts (MacDock.wallpaperFor): MacShell's last pick, else Plasma's configured
// image. The wallpaper picker only updates that pick in this mode (MacBar.awwwScript), so the two never disagree.
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    property var hub: null
    readonly property var dock: hub ? hub.dock : null
    readonly property bool active: !!hub && !!hub.compositor && hub.compositor.desktopUnserved

    // Plasma's configured image is read by the shared wallpaper lookup, which otherwise only runs while some glass wants it
    onActiveChanged: if (active) hub.refreshWallpaper()

    // KSplash closes at its sixth stage; plasmashell sends the last one, "desktop" (shellcorona.cpp). Duplicates are ignored.
    // --auto-start=no: outside a login the name is free, and D-Bus activation would only start a plasma_waitforname stub.
    property bool splashDone: false
    function finishSplash() {
        if (splashDone) return;
        splashDone = true;
        Quickshell.execDetached(["busctl", "--user", "--auto-start=no", "call", "org.kde.KSplash", "/KSplash",
                                 "org.kde.KSplash", "setStage", "s", "desktop"]);
    }
    // no wallpaper found (or it never loads): don't hold the splash for its full timeout
    Timer { interval: 3000; running: root.active && !root.splashDone; onTriggered: root.finishSplash() }

    // Unlocking can make the windows below anew (the screens come back as new outputs). Qt forgets an unused decode within
    // ~30 s, so a big photo took seconds to decode again behind a black window. These hidden copies, one per screen, hold
    // the picture each screen last showed (same file, size and fill mode = the same decoded copy, no extra memory).
    property var shown: ({})     // screen name -> { source, size }
    function remember(name, source, size) {
        var live = {}, next = {};
        for (var i = 0; i < Quickshell.screens.length; i++) live[Quickshell.screens[i].name] = true;
        for (var k in shown) if (live[k] && k !== name) next[k] = shown[k];   // an unplugged screen's copy goes
        next[name] = { source: source, size: size };
        shown = next;
    }
    Instantiator {
        model: root.active ? Object.keys(root.shown) : []
        Image {
            required property string modelData
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: root.shown[modelData].size
            source: root.shown[modelData].source
        }
    }

    Variants {
        model: root.active ? Quickshell.screens : []
        PanelWindow {
            id: wall
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            // "desktop" makes KWin treat it as the desktop window (layershellv1window.cpp, scopeToType), as Plasma's is:
            // Overview and Show Desktop handle it like Plasma's wallpaper.
            WlrLayershell.namespace: "desktop"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // Never takes the pointer: clicks on the desktop belong to the Desktop layer above. Unless that layer is off
            // (no desktop icons) and "Click wallpaper to reveal desktop" is on: then the click lands here.
            readonly property bool peekHere: !!root.dock && root.dock.desktopPeek && !root.dock.desktopIcons
            mask: Region { item: wall.peekHere ? peekArea : null }
            MouseArea {
                id: peekArea
                anchors.fill: parent
                enabled: wall.peekHere
                onClicked: { if (root.hub.popWho) root.hub.popWho = null; else root.dock.peekDesktop(); }
            }

            Image {
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                // decoded at the screen's physical size: sharp on HiDPI, no full-size copy of a large photo in memory
                // (the screen's size, not the item's: that is 0 until the surface is configured, which would load it twice).
                // hub.wallpaperSize: the same size the glass backdrops ask for, so they share this decoded copy
                sourceSize: root.hub.wallpaperSize(modelData.name)
                source: root.dock ? root.dock.fileUrl(root.dock.wallpaperFor(modelData.name)) : ""
                onStatusChanged: {
                    if (status === Image.Ready) root.remember(modelData.name, source, sourceSize);
                    if (status === Image.Ready || status === Image.Error) root.finishSplash();
                }
            }
        }
    }
}
