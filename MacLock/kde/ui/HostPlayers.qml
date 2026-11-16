// The media player KDE treats as current, under the names LockScreen.qml uses for Quickshell's MprisPlayer.
// Host.qml loads this by URL: org.kde.plasma.private.mpris is private to Plasma, so if a Plasma update changes it,
// only Now Playing goes missing and the lock screen still loads.
import QtQuick
import org.kde.plasma.private.mpris as Mpris

Item {
    id: w
    Mpris.Mpris2Model { id: players }
    readonly property var src: players.currentPlayer
    readonly property var player: src ? facade : null

    QtObject {
        id: facade
        readonly property bool isPlaying: !!w.src && w.src.playbackStatus === Mpris.PlaybackStatus.Playing
        readonly property string trackTitle: w.src ? w.src.track : ""
        readonly property string trackArtist: w.src ? w.src.artist : ""
        readonly property string trackAlbum: w.src ? w.src.album : ""
        readonly property string trackArtUrl: w.art
        readonly property string identity: w.src ? w.src.identity : ""
        readonly property real length: w.src ? w.src.length / 1e6 : 0        // KDE counts microseconds
        readonly property bool lengthSupported: length > 0
        readonly property bool positionSupported: true
        readonly property bool canSeek: !!w.src && w.src.canSeek
        readonly property bool canGoNext: !!w.src && w.src.canGoNext
        readonly property bool canGoPrevious: !!w.src && w.src.canGoPrevious
        readonly property bool canTogglePlaying: !!w.src && (w.src.canPlay || w.src.canPause)
        // KDE's model does not pass the raw MPRIS fields on: Spotify Canvas is looked up by artist and title instead
        readonly property var metadata: ({})
        readonly property string uniqueId: ""
        function togglePlaying() { if (w.src) w.src.PlayPause(); }
        function next() { if (w.src) w.src.Next(); }
        function previous() { if (w.src) w.src.Previous(); }
    }

    // ── position in seconds: KDE only reports it when asked, so it is estimated from the last report in between
    property real base: 0
    property double at: 0
    property bool ticking: false
    function estimate() { return base + (ticking ? (Date.now() - at) / 1000 : 0); }
    function mark(seconds) { base = seconds; at = Date.now(); ticking = facade.isPlaying; }
    onSrcChanged: mark(src ? src.position / 1e6 : 0)
    Connections {
        target: w.src
        function onPositionChanged() { w.mark(w.src.position / 1e6); }
        function onPlaybackStatusChanged() { w.mark(w.estimate()); }
    }
    function position() {
        if (!src) return 0;
        src.updatePosition();
        return estimate();
    }
    function seek(seconds) { if (src) src.position = Math.round(seconds * 1e6); }

    // ── cover art: KDE's lock screen loads no images from the network, so a remote cover is downloaded to a file
    property string art: ""
    readonly property string artUrl: src ? src.artUrl : ""
    onArtUrlChanged: {
        artGet.cancel();
        if (/^https?:\/\//.test(artUrl)) { art = ""; artGet.run(["sh", "-c", artScript, "sh", artUrl]); }
        else art = artUrl;
    }
    readonly property string artScript: [
        'd="$HOME/.cache/maclock/art"; mkdir -p "$d"; find "$d" -type f -mtime +7 -delete 2>/dev/null',
        'f="$d/$(printf %s "$1" | md5sum | cut -c1-16)"',
        '[ -s "$f" ] || curl -sfL --max-time 8 -o "$f" "$1" || rm -f "$f"',
        '[ -s "$f" ] && printf %s "$f"'
    ].join("\n")
    Run { id: artGet; onDone: out => w.art = out.trim() !== "" ? "file://" + out.trim() : "" }
}
