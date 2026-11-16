// One helper process: run(argv) starts it (replacing a run still in flight) and done(text) carries its output.
// Quickshell side; kde/ui/Run.qml is the same thing for KDE's lock screen.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: r
    signal done(string text)
    function run(argv) { proc.running = false; proc.command = argv; proc.running = true; }
    function cancel() { proc.running = false; }
    function detached(argv) { Quickshell.execDetached(argv); }
    Process {
        id: proc
        stdout: StdioCollector { onStreamFinished: r.done(text) }
    }
}
