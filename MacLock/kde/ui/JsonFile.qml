// The text of a file under $HOME, kept current ("" while it is missing). KDE side of ../../JsonFile.qml.
import QtQuick

Item {
    id: j
    property string rel: ""         // path below $HOME
    property bool active: true
    property string text: ""
    Run { id: reader; onDone: out => j.text = out }
    // shortcut: polls every 2 s because plain QML has no file watcher here; move to one if KDE's lock screen gains it
    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: j.active && j.rel !== ""
        onTriggered: reader.run(["sh", "-c", 'cat "$HOME/$1" 2>/dev/null', "sh", j.rel])
    }
}
