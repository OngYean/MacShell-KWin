.pragma library
// Per-panel look (Settings → Appearance → Panels): reads the two maps the Dock saves in ~/.config/macdock/settings.json.

// A zone that was split off from another follows that one until it is picked itself, so a saved choice still covers it:
// the Dock's labels and right-click menu ("dockmenus") were part of "dock".
var follows = { dockmenus: "dock" };

// Does the panel `zone` use KWin's blur? `map` is panelBlur (zone → true / false). A zone it doesn't list follows the
// zone it was split from, or else `all`, the old switch for every panel at once.
function kwin(map, zone, all) {
    var v = map ? map[zone] : undefined;
    if (typeof v === "boolean") return v;
    return follows[zone] ? kwin(map, follows[zone], all) : all === true;
}

// The panel's own tint from panelTint, 0 (clear) to 1 (solid); undefined when it has none, so the caller uses the global one.
function tint(map, zone) {
    var v = map ? map[zone] : undefined;
    if (typeof v === "number" && isFinite(v)) return Math.max(0, Math.min(1, v));
    return follows[zone] ? tint(map, follows[zone]) : undefined;
}
