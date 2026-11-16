// A silent, looping video that fills its Loader: the animated wallpaper and the Spotify Canvas.
// Its own file, loaded by URL, so LockScreen.qml still loads where QtMultimedia is not installed.
import QtQuick
import QtMultimedia

Item {
    id: v
    property string src: ""     // file path, set by the Loader once this exists
    MediaPlayer {
        source: v.src !== "" ? "file://" + v.src : ""
        loops: MediaPlayer.Infinite
        videoOutput: out
        onSourceChanged: if (v.src !== "") play()
    }
    VideoOutput { id: out; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop }
}
