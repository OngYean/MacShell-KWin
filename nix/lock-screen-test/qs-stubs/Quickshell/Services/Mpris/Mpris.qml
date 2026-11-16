pragma Singleton
import QtQuick

// one paused player, in Quickshell's MprisPlayer names (seconds)
QtObject {
    property QtObject players: QtObject {
        property var values: [player]
    }
    property QtObject player: QtObject {
        property bool isPlaying: false
        property string trackTitle: "Song"
        property string trackArtist: "Artist"
        property string trackAlbum: "Album"
        property string trackArtUrl: ""
        property string identity: "Player"
        property string uniqueId: ""
        property var metadata: ({})
        property real length: 200
        property real position: 5
        property bool lengthSupported: true
        property bool positionSupported: true
        property bool canSeek: true
        property bool canGoNext: true
        property bool canGoPrevious: false
        property bool canTogglePlaying: true
        function togglePlaying() { }
        function next() { }
        function previous() { }
    }
}
