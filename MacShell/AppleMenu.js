.pragma library

// The items of the top-left ("Apple") menu, in the order they are shown: Settings → Menu Bar → Apple Menu Items, saved
// as "appleMenuItems" in ~/.config/macbar/settings.json. An entry is { id, label, command }:
//   id       one of `builtin`, "sep" (a separator) or "custom"
//   label    the name of a custom item (ignored for the others)
//   command  a custom item's shell command. On a built-in item: "" keeps what the item does, anything else runs instead

var builtin = ["about", "settings", "recent", "forcequit", "sleep", "restart", "shutdown", "lock", "logout"];
var names = {
    about: "About This Linux", settings: "System Settings…", recent: "Recent Items", forcequit: "Force Quit…",
    sleep: "Sleep", restart: "Restart…", shutdown: "Shut Down…", lock: "Lock Screen", logout: "Log Out…",
    sep: "Separator", custom: "Custom item"
};

function entry(id) { return { id: id, label: id === "custom" ? "New Item" : "", command: "" }; }

function defaults() {
    return ["about", "sep", "settings", "sep", "recent", "sep", "forcequit", "sep", "sleep", "restart", "shutdown", "sep", "lock", "logout"].map(entry);
}

// Whatever was saved (or typed into settings.json) as a clean list. Not a list at all: the defaults. Entries with an
// unknown id are dropped, and a built-in item appears once.
function clean(list) {
    if (!Array.isArray(list)) return defaults();
    var out = [], seen = {};
    for (var i = 0; i < list.length; i++) {
        var e = list[i];
        if (!e || typeof e !== "object" || typeof e.id !== "string") continue;
        var known = builtin.indexOf(e.id) >= 0;
        if (!known && e.id !== "sep" && e.id !== "custom") continue;
        if (known) { if (seen[e.id]) continue; seen[e.id] = true; }
        out.push({ id: e.id, label: e.id === "custom" && typeof e.label === "string" ? e.label : "",
                   command: e.id !== "sep" && typeof e.command === "string" ? e.command : "" });
    }
    return out;
}

// the built-in items that are not in the list (Settings offers to add them back)
function missing(list) {
    return builtin.filter(function (id) { return !list.some(function (e) { return e.id === id; }); });
}

// Each of these returns a new list; the one handed in is left alone.
function move(list, i, by) {
    var j = i + by, out = list.slice();
    if (i < 0 || i >= out.length || j < 0 || j >= out.length) return out;
    out.splice(j, 0, out.splice(i, 1)[0]);
    return out;
}
function remove(list, i) { return list.filter(function (e, n) { return n !== i; }); }
function add(list, id) { return list.concat([entry(id)]); }
function set(list, i, key, value) {
    return list.map(function (e, n) {
        if (n !== i) return e;
        var c = { id: e.id, label: e.label, command: e.command };
        c[key] = value;
        return c;
    });
}

// What the menu shows: separators at either end and repeated separators are left out, and a custom item needs a name.
function shown(list) {
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var e = list[i];
        if (e.id === "custom" && e.label.trim() === "") continue;
        if (e.id === "sep" && (out.length === 0 || out[out.length - 1].id === "sep")) continue;
        out.push(e);
    }
    if (out.length > 0 && out[out.length - 1].id === "sep") out.pop();
    return out;
}

// the most recently started applications, newest first, each once
function pushRecent(ids, id, max) {
    return [id].concat(ids.filter(function (x) { return x !== id; })).slice(0, max);
}
