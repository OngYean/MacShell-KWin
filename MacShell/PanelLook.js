.pragma library
// Per-panel look (Settings → Appearance → Panels): reads the two maps the Dock saves in ~/.config/macdock/settings.json.

// Does the panel `zone` use KWin's blur? `map` is panelBlur (zone → true / false). A zone it doesn't list follows `all`,
// the old switch for every panel at once.
function kwin(map, zone, all) {
    var v = map ? map[zone] : undefined;
    return typeof v === "boolean" ? v : all === true;
}

// The panel's own tint from panelTint, 0 (clear) to 1 (solid); undefined when it has none, so the caller uses the global one.
function tint(map, zone) {
    var v = map ? map[zone] : undefined;
    return typeof v === "number" && isFinite(v) ? Math.max(0, Math.min(1, v)) : undefined;
}
