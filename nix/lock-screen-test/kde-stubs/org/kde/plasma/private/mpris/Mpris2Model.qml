// Stand-in for KDE's Mpris2Model (org.kde.plasma.private.mpris): one paused player, in KDE's names and units.
import QtQuick

QtObject {
    property QtObject currentPlayer: QtObject {
        property int playbackStatus: 3
        property string track: "Song"
        property string artist: "Artist"
        property string album: "Album"
        property string artUrl: ""
        property string identity: "Player"
        property double length: 200000000      // microseconds
        property double position: 5000000
        property bool canSeek: true
        property bool canGoNext: true
        property bool canGoPrevious: false
        property bool canPlay: true
        property bool canPause: true
        // PlayPause(), Next() and Previous() are missing: QML cannot declare methods with a capital first letter
        function updatePosition() { }
    }
}
