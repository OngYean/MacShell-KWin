// test-wallpaper-size.js — checks that every wallpaper Image asks for the one decode size per screen (hub.wallpaperSize in
// MacShell/shell.qml). Qt keeps a decoded copy per file and requested size, so one stray size is another screen-sized
// picture in memory.
//   node nix/test-wallpaper-size.js        (no Qt, Plasma or Nix needed)
const fs = require("fs"), path = require("path"), vm = require("vm"), assert = require("assert");
const read = f => fs.readFileSync(path.join(__dirname, "../MacShell", f), "utf8");

// ── the function itself, lifted out of shell.qml ──
const shell = read("shell.qml");
const at = shell.indexOf("function wallpaperSize(screenName)");
assert.ok(at >= 0, "shell.qml has wallpaperSize()");
let depth = 0, end = -1;
for (let i = shell.indexOf("{", at); i < shell.length; i++) {
    if (shell[i] === "{") depth++;
    else if (shell[i] === "}" && --depth === 0) { end = i + 1; break; }
}
const screens = [{ name: "eDP-1", width: 1600, height: 1000, devicePixelRatio: 2 }, { name: "HDMI-A-1", width: 3840, height: 2160, devicePixelRatio: 1 }];
function sizeOf(name, unserved, list) {
    const ctx = { Quickshell: { screens: list || screens }, facade: { desktopUnserved: unserved }, Qt: { size: (w, h) => w + "x" + h }, Math, out: {} };
    vm.runInNewContext(shell.slice(at, end) + "\nout.f = wallpaperSize;", ctx);
    return ctx.out.f(name);
}
assert.strictEqual(sizeOf("eDP-1", false), "1600x1000", "logical size while someone else draws the desktop");
assert.strictEqual(sizeOf("eDP-1", true), "3200x2000", "physical size while MacShell draws the desktop");
assert.strictEqual(sizeOf("HDMI-A-1", true), "3840x2160", "each screen its own size");
assert.strictEqual(sizeOf("gone", false), "1600x1000", "an unknown screen gets the first screen's size, never 0x0 (undecimated)");
assert.strictEqual(sizeOf("", false, []), "1920x1080", "no screens at all: still not 0x0");

// ── every Image that shows the wallpaper uses it ──
// (the widgets take it as wallSize from WidgetVisual.qml)
const uses = { "MacBar.qml": 1, "MacDock.qml": 3, "Desktop.qml": 1, "Wallpaper.qml": 1, "WidgetVisual.qml": 4 };
for (const f in uses) {
    const n = (read(f).match(/sourceSize: .*wallpaperSize\(|wallSize: .*wallpaperSize\(/g) || []).length;
    assert.strictEqual(n, uses[f], f + ": " + uses[f] + " wallpaper Image(s) on the shared size, found " + n);
}
for (const f of ["CardWidget.qml", "CalendarWidget.qml", "ClockWidget.qml", "PlayerWidget.qml", "WeatherWidget.qml"])
    assert.ok(/source: w\.wallUrl[\s\S]{0,300}sourceSize: w\.wallSize/.test(read(f)), f + ": the wallpaper Image decodes at wallSize");
for (const f of fs.readdirSync(path.join(__dirname, "../MacShell")).filter(n => n.endsWith(".qml")))
    assert.ok(!/sourceSize\.width: (bd\.width|w\.screenW|prefsGlassGeo\.mw)\b/.test(read(f)), f + ": a wallpaper Image still asks for a size of its own");
console.log("ok: wallpaper decode size");
