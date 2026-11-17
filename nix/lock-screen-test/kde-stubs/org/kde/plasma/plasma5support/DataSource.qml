// Stand-in for Plasma's DataSource with the "executable" engine (org.kde.plasma.plasma5support), for
// nix/test-lock-screen.sh: no process is started, each command "exits" on the next event-loop turn with canned output.
import QtQuick

QtObject {
    id: ds
    property string engine: ""
    signal newData(string sourceName, var data)
    property var live: ({})

    function connectSource(cmd) {
        live[cmd] = true;
        Qt.callLater(function () {
            if (ds.live[cmd]) ds.newData(cmd, { "exit code": 0, "stdout": ds.answer(cmd) });
        });
    }
    function disconnectSource(cmd) { delete live[cmd]; }

    function answer(cmd) {
        // LockState.qml's one-shot lookups: MacShell's settings, MacLock's own, the video state, Wi-Fi, Ethernet, the main display
        if (cmd.indexOf("macbar/settings.json") >= 0)
            return ['{"use24h": false, "wallpaperPath": "/tmp/wall.png", "lockClockFont": "serif", "language": "auto"}', "",
                    '{"mediaSlot": "bottom"}', "", "", "", "50", "eth", '{"primary": "DP-1", "modes": {}}'].join("\n@@maclock@@\n") + "\n";
        // … and which of the wallpaper candidates exist: only the first
        if (cmd.indexOf('[ -f "$f" ]') >= 0) return "y\nn\nn\nn\n";
        return "";
    }
}
