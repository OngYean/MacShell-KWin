// test-kde-colors.js — checks MacShell/KdeColors.js (the kdeglobals reader behind "Follow KDE's accent colour").
//   node nix/test-kde-colors.js            (no Qt, Plasma or Nix needed)
const fs = require("fs"), path = require("path"), vm = require("vm"), assert = require("assert");
// a QML JavaScript library: everything but its ".pragma" line is plain JavaScript
const src = fs.readFileSync(path.join(__dirname, "../MacShell/KdeColors.js"), "utf8").replace(/^\.pragma .*$/m, "");
const lib = {};
vm.runInNewContext(src + "\nout.color = color; out.accent = accent;", { out: lib });

const globals = [
    "[Colors:Button]", "BackgroundNormal=49,54,59",
    "[Colors:Selection]", "BackgroundAlternate=30,87,116", "BackgroundNormal=61,174,233", "ForegroundNormal=252,252,252",
    "[General]", "AccentColor=233,61,130,255", "ColorScheme=BreezeDark",
    "[KDE]", "widgetStyle=Breeze",
].join("\n");

assert.strictEqual(lib.color(globals, "Colors:Selection", "BackgroundNormal"), "#3daee9", "r,g,b in the named group");
assert.strictEqual(lib.color(globals, "Colors:Button", "BackgroundNormal"), "#31363b", "the same key in another group");
assert.strictEqual(lib.color(globals, "General", "AccentColor"), "#e93d82", "r,g,b,a drops the alpha");
assert.strictEqual(lib.color("[General]\nAccentColor=#0A84FF", "General", "AccentColor"), "#0a84ff", "#rrggbb");
assert.strictEqual(lib.color(globals, "General", "ColorScheme"), "", "not a colour");
assert.strictEqual(lib.color(globals, "Colors:View", "BackgroundNormal"), "", "missing group");
assert.strictEqual(lib.color("", "General", "AccentColor"), "", "empty file");
assert.strictEqual(lib.color("[General]\nAccentColor=999,0,0", "General", "AccentColor"), "#ff0000", "clamped to 255");

assert.strictEqual(lib.accent(globals), "#3daee9", "the selection colour wins: it is what Plasma paints with");
assert.strictEqual(lib.accent("[General]\nAccentColor=233,61,130"), "#e93d82", "AccentColor when no scheme colours are stored");
assert.strictEqual(lib.accent("[General]\nColorScheme=BreezeLight"), "", "neither: MacShell keeps its own accent");
console.log("ok: KdeColors.js");
