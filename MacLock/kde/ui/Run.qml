// One helper process: run(argv) starts it (replacing a run still in flight) and done(text) carries its output.
// KDE side of ../../Run.qml: KDE's lock screen cannot load Quickshell, so this goes through Plasma's "executable"
// data engine, which runs a shell command line and reports once the command has exited.
import QtQuick
import org.kde.plasma.plasma5support as P5Support

Item {
    id: r
    signal done(string text)
    property string current: ""     // the command line done() is waited for
    property int runs: 0

    function quote(arg) { return "'" + String(arg).replace(/'/g, "'\\''") + "'"; }
    function line(argv) { return argv.map(quote).join(" "); }

    function run(argv) {
        cancel();
        // the engine names a run after its command line: the trailing shell comment makes a repeat a new run
        current = line(argv) + " #" + (++runs);
        engine.connectSource(current);
    }
    function cancel() {
        if (current === "") return;
        engine.disconnectSource(current);       // also ends the process
        current = "";
    }
    // survives this process: the lock screen exits right after the unlock sound starts
    function detached(argv) { engine.connectSource("( " + line(argv) + " >/dev/null 2>&1 & ) #" + (++runs)); }

    P5Support.DataSource {
        id: engine
        engine: "executable"
        onNewData: (source, data) => {
            if (data["exit code"] === undefined) return;      // not finished yet
            engine.disconnectSource(source);
            if (source !== r.current) return;                 // a detached run, or one that was replaced
            r.current = "";
            r.done(data["stdout"] || "");
        }
    }
}
