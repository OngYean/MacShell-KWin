.pragma library
// Reads KDE Plasma's colours from the text of ~/.config/kdeglobals (MacDock.qml, "Follow KDE's accent colour").

// The value of `key` in the INI group `group` as "#rrggbb"; "" when it is missing or not a colour.
// Plasma writes colours as "r,g,b" (sometimes "r,g,b,a") or as "#rrggbb".
function color(text, group, key) {
    var inGroup = false, lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i].trim();
        if (l.charAt(0) === "[") { inGroup = l === "[" + group + "]"; continue; }
        if (!inGroup || l.indexOf(key + "=") !== 0) continue;
        var v = l.substring(key.length + 1).trim(), m = /^(\d{1,3}),(\d{1,3}),(\d{1,3})(,\d{1,3})?$/.exec(v);
        if (m) {
            return "#" + [m[1], m[2], m[3]].map(function (n) {
                return ("0" + Math.min(255, Number(n)).toString(16)).slice(-2);
            }).join("");
        }
        return /^#[0-9a-fA-F]{6}$/.test(v) ? v.toLowerCase() : "";
    }
    return "";
}

// The highlight colour Plasma paints with: its accent (hand-picked or from the wallpaper) as applied to the colour scheme,
// or the scheme's own. [General] AccentColor is only the fallback: plasma-apply-colorscheme --accent-color changes the
// selection colour without writing it. "" when kdeglobals holds neither (a scheme that was never changed).
function accent(text) {
    return color(text, "Colors:Selection", "BackgroundNormal") || color(text, "General", "AccentColor");
}
