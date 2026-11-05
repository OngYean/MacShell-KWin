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
    Region { id: all; regions: bc.parts.filter(p => p.on) }
    Component.onCompleted: if (compositor && compositor.can("backgroundEffect")) window.BackgroundEffect.blurRegion = all
}
