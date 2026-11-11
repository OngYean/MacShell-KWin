// BlurCollector — one per window that holds glass. Gives KWin the union of the GlassBlur outlines inside the window as the
// window's blur region (ext-background-effect, through Quickshell's BackgroundEffect). Declare it directly inside the window:
// GlassBlur.qml looks for it among the window's top-level items.
import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: bc
    objectName: "glassBlurCollector"
    required property var window          // the window this is declared in
    property var compositor: null         // hub.compositor: the region is only handed over where KWin's blur protocol exists
    property var parts: []
    function add(r) { if (parts.indexOf(r) < 0) parts = parts.concat([r]); }
    function remove(r) { parts = parts.filter(p => p !== r); }
    // KWin's blur (and Better Blur DX's cache) size their textures by the bounding box of the window's whole region: a box
    // that changes every frame (the Dock widening under magnification, a hover label coming and going) makes them start
    // over, and the blur visibly re-renders. A window with such surfaces names the area they move in here; two 1 px regions
    // at its corners then keep the box the same size.
    // shortcut: those two pixels are blurred too, drop this once KWin keeps its textures across a resized region
    property rect holdRect: Qt.rect(0, 0, 0, 0)
    readonly property var live: parts.filter(p => p.on)
    Region { id: holdA; x: bc.holdRect.x; y: bc.holdRect.y; width: 1; height: 1 }
    Region { id: holdB; x: bc.holdRect.x + bc.holdRect.width - 1; y: bc.holdRect.y + bc.holdRect.height - 1; width: 1; height: 1 }
    Region { id: all; regions: (bc.live.length > 0 && bc.holdRect.width > 1 && bc.holdRect.height > 1) ? bc.live.concat([holdA, holdB]) : bc.live }
    Component.onCompleted: if (compositor && compositor.can("backgroundEffect")) window.BackgroundEffect.blurRegion = all
}
