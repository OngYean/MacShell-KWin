// What LockScreen.qml needs from the session around it: the battery, the current media player, and a way to reach
// the running shell. KDE side of ../../Host.qml, for KDE's lock screen, which cannot load Quickshell's modules.
import QtQuick

Item {
    id: host
    // where spotify-canvas.py and genius-lyrics.py are: next to this file
    readonly property string scriptDir: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, ""))

    // ── battery, straight from the kernel: no Plasma module to depend on
    property bool batteryPresent: false
    property real batteryPct: 0
    property bool batteryCharging: false
    Run {
        id: battery
        onDone: out => {
            var l = out.split("\n"), pct = parseInt(l[0]);
            host.batteryPresent = !isNaN(pct);
            host.batteryPct = isNaN(pct) ? 0 : pct;
            host.batteryCharging = /^(Charging|Full)$/.test((l[1] || "").trim());
        }
    }
    Timer {
        interval: 30000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: battery.run(["sh", "-c", 'for b in /sys/class/power_supply/BAT*; do [ -r "$b/capacity" ] && { cat "$b/capacity" "$b/status"; break; }; done'])
    }

    // ── media player (HostPlayers.qml); null while nothing plays or if that file cannot load
    Loader { id: players; source: "HostPlayers.qml" }
    readonly property var player: players.item ? players.item.player : null
    function position(pl) { return players.item ? players.item.position() : 0; }
    function seek(pl, seconds) { if (players.item) players.item.seek(seconds); }

    Run { id: shell }
    function shellIpc(args) { shell.detached(["macshell", "ipc", "call"].concat(args)); }
}
