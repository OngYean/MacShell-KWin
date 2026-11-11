// GlassBlur — the outline of one glass surface, for KWin's blur (Settings → Appearance → Panels, "KWin blur").
//
// Put it inside the surface with `target` = the item whose (rounded) rectangle is the glass. It hands itself to the
// BlurCollector of its window (found by objectName among the window's top-level items), which gives KWin the union of all
// of them. Empty while `on` is false or the surface is hidden or faded out; costs nothing then.
import QtQuick
import Quickshell

Region {
    id: gb
    property Item target: null
    property bool on: false
    property real cornerR: 0

    // Where the target is in the window, and how visible. Region only watches its item's own x / y / size, so this reads
    // everything else that can move it (only while on): every ancestor's position, size, scale and opacity, and the entries
    // of its `transform` list (a slide-in Translate, a pop-in Scale). It re-runs when any of them changes.
    readonly property var probe: {
        if (!on || !target) return null;
        var o = 1, watched = 0;
        for (var it = target; it; it = it.parent) {
            o *= it.opacity;
            watched += it.x + it.y + it.width + it.height + it.scale;
            var tf = it.transform;
            for (var i = 0; i < tf.length; i++) {
                var t = tf[i];
                watched += (t.x || 0) + (t.y || 0) + (t.xScale || 0) + (t.yScale || 0) + (t.angle || 0);
            }
        }
        var r = target.mapToItem(null, 0, 0, target.width, target.height);
        return { opacity: o, x: r.x, y: r.y, w: r.width, h: r.height, watched: watched };
    }
    // hidden, faded out, or warmed up invisibly at opacity 0.01: no blur
    readonly property bool shown: probe !== null && target.visible && probe.w > 0 && probe.h > 0 && probe.opacity > 0.05
    item: shown ? target : null
    // x / y / width / height are ignored while `item` is set, but each change rebuilds the region. They carry the rectangle
    // Region will compute for the item (same rounding), so the region is rebuilt exactly when the surface moves or resizes
    // on screen, and not while it only fades: every rebuild makes KWin's blur redo its work.
    x: shown ? Math.floor(probe.x) : 0
    y: shown ? Math.floor(probe.y) : 0
    width: shown ? Math.ceil(probe.w) : 0
    height: shown ? Math.ceil(probe.h) : 0
    radius: shown ? Math.round(cornerR * probe.w / target.width) : 0

    // registration: the BlurCollector declared directly in this surface's window, found among the children of one of the
    // target's ancestors. Not only the topmost one's: the window's content item is the top of the tree until Quickshell
    // creates the window, and is then parented to the QQuickWindow's own root item (ProxyWindowBase), one level further up.
    // Looking only there found no collector once a window existed, so nothing was ever blurred.
    readonly property Item windowRoot: { var t = null; for (var it = target; it; it = it.parent) t = it; return t; }
    property var collector: null
    function attach() {
        var c = null;
        for (var it = target; it && !c; it = it.parent) {
            var kids = it.children;
            for (var i = 0; i < kids.length && !c; i++) if (kids[i].objectName === "glassBlurCollector") c = kids[i];
        }
        if (c === collector) return;
        if (collector) collector.remove(gb);
        collector = c;
        if (c) c.add(gb);
    }
    onWindowRootChanged: attach()
    Component.onCompleted: attach()
    Component.onDestruction: if (collector) collector.remove(gb)
}
