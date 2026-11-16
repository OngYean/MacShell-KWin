// The text of a file under $HOME, kept current ("" while it is missing). Quickshell side: a watched FileView;
// kde/ui/JsonFile.qml is the same thing for KDE's lock screen.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: j
    property string rel: ""         // path below $HOME
    property bool active: true      // only the KDE side polls, and stops when this is off
    readonly property string text: file.loaded ? file.text() : ""
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/" + j.rel
        watchChanges: true; printErrors: false
        onFileChanged: reload()
    }
}
