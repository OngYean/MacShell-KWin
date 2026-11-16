import QtQuick

QtObject {
    property string path: ""
    property bool watchChanges: false
    property bool printErrors: true
    property bool loaded: false
    signal fileChanged()
    function text() { return ""; }
    function reload() { }
}
