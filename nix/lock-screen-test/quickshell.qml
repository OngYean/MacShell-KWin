// Loads MacLock's UI with its Quickshell-side files (Host.qml, Run.qml, JsonFile.qml) against stand-ins for
// Quickshell's modules: a check that the files still fit together, not that they work under Hyprland.
// nix/test-lock-screen.sh puts this file next to a copy of MacLock/.
import QtQuick
import "MacLock" as MacLock

Item {
    id: t
    width: 1280; height: 800

    // the fields shell.qml's lockState has
    QtObject {
        id: state
        property var now: new Date()
        property string wallpaper: ""
        property string wallpaperVideo: ""
        property string userName: "Test User"
        property string avatar: ""
        property int wifiLevel: 2
        property bool ethernet: false
        property string pass: ""
        property bool busy: false
        property int fails: 0
        property string message: ""
        property bool engaged: false
        property bool unlocking: false
        property string mediaSlot: "top"
        property bool capsLock: false
        property bool use24h: true
        property var clockCfg: ({})
        property bool artBg: true
        property string npMode: ""
        function poke() { engaged = true; }
        function submit() { }
        function checkCaps() { }
        function setMediaSlot(v) { mediaSlot = v; }
    }

    MacLock.LockScreen { id: view; anchors.fill: parent; st: state }

    Timer {
        interval: 300; running: true
        onTriggered: {
            var ok = view.hasMedia && view.player.trackTitle === "Song";
            if (!ok) { console.error("lock-screen-test: FAIL the UI does not see Quickshell's current player"); Qt.exit(1); return; }
            console.log("lock-screen-test: PASS (quickshell)");
            Qt.exit(0);
        }
    }
}
