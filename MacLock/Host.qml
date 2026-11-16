// What LockScreen.qml needs from the session around it: the battery, the current media player, and a way to reach
// the running shell. This is the Quickshell side (Hyprland); kde/ui/Host.qml is the same thing for KDE's lock screen.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

Item {
    // where spotify-canvas.py and genius-lyrics.py are installed
    readonly property string scriptDir: Quickshell.env("HOME") + "/.config/quickshell/MacLock"

    readonly property bool batteryPresent: !!UPower.displayDevice && UPower.displayDevice.isPresent
    readonly property real batteryPct: {
        var d = UPower.displayDevice;
        if (!d) return 0;
        return Math.round(d.percentage <= 1.0 ? d.percentage * 100 : d.percentage);
    }
    readonly property bool batteryCharging: !!UPower.displayDevice
        && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)

    // the playing player, else the first one that has a track
    readonly property var player: {
        var ps = Mpris.players.values, best = null;
        for (var i = 0; i < ps.length; i++) {
            if (ps[i].isPlaying) return ps[i];
            if (!best && ps[i].trackTitle) best = ps[i];
        }
        return best;
    }
    // seconds; MprisPlayer only recomputes its position when asked
    function position(pl) { pl.positionChanged(); return pl.position; }
    function seek(pl, seconds) { pl.position = seconds; }

    function shellIpc(args) { Quickshell.execDetached(["qs", "-c", "MacShell", "ipc", "call"].concat(args)); }
}
