// GlassBlur — the outline of one glass surface, for KWin's blur (Settings → Appearance → "Use KWin's blur").
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

    // Region follows only its item's own x / y / size. This reads every ancestor's position, scale and opacity (only while
    // on), so it re-runs whenever a popover slides, scales or fades.
    readonly property var probe: {
        if (!on || !target) return null;
        var o = 1, s = 1, px = 0, py = 0;
        for (var it = target; it; it = it.parent) { o *= it.opacity; s *= it.scale; px += it.x; py += it.y; }
        return { opacity: o, scale: s, x: px, y: py };
    }
    // hidden, faded out, or warmed up invisibly at opacity 0.01: no blur
    readonly property bool shown: probe !== null && target.visible && target.width > 0 && target.height > 0 && probe.opacity > 0.05
    item: shown ? target : null
    // x / y / width / height are ignored while `item` is set, but each change rebuilds the region. They carry the ancestors'
    // position, scale and opacity, so the blur follows a surface that moves, scales or fades (also through `transform: Scale`,
    // which Region maps correctly but doesn't watch: the animations that drive it change the opacity too).
    x: shown ? Math.round(probe.x) : 0
    y: shown ? Math.round(probe.y) : 0
    width: shown ? Math.round(probe.scale * 1000) : 0
    height: shown ? Math.round(probe.opacity * 100) : 0
    radius: shown ? Math.round(cornerR * probe.scale) : 0

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
