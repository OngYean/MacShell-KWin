// test-panel-look.js — checks MacShell/PanelLook.js (the per-panel blur and tint lookups behind Settings → Appearance → Panels).
//   node nix/test-panel-look.js            (no Qt, Plasma or Nix needed)
const fs = require("fs"), path = require("path"), vm = require("vm"), assert = require("assert");
const src = fs.readFileSync(path.join(__dirname, "../MacShell/PanelLook.js"), "utf8").replace(/^\.pragma .*$/m, "");
const lib = {};
vm.runInNewContext(src + "\nout.kwin = kwin; out.tint = tint;", { out: lib });

assert.strictEqual(lib.kwin({ dock: false, menus: true }, "dock", true), false, "a picked panel ignores the old switch (off)");
assert.strictEqual(lib.kwin({ dock: false, menus: true }, "menus", false), true, "a picked panel ignores the old switch (on)");
assert.strictEqual(lib.kwin({ dock: false }, "cc", true), true, "a panel never picked follows the old switch");
assert.strictEqual(lib.kwin({}, "cc", false), false, "nothing picked, switch off");
assert.strictEqual(lib.kwin({ cc: "yes" }, "cc", false), false, "not a boolean: as if never picked");
assert.strictEqual(lib.kwin(null, "cc", true), true, "no map at all");

assert.strictEqual(lib.tint({ dock: 0.1 }, "dock"), 0.1, "the panel's own tint");
assert.strictEqual(lib.tint({ dock: 0 }, "dock"), 0, "0 is a value (fully clear), not 'unset'");
assert.strictEqual(lib.tint({ dock: 0.1 }, "bar"), undefined, "no tint of its own");
assert.strictEqual(lib.tint({ dock: 7 }, "dock"), 1, "clamped to 1");
assert.strictEqual(lib.tint({ dock: -1 }, "dock"), 0, "clamped to 0");
assert.strictEqual(lib.tint({ dock: "0.5" }, "dock"), undefined, "not a number");
assert.strictEqual(lib.tint({ dock: NaN }, "dock"), undefined, "NaN");
assert.strictEqual(lib.tint(null, "dock"), undefined, "no map at all");

// the Dock's labels and menu have their own row, and follow the Dock's until it is used
assert.strictEqual(lib.kwin({ dock: true }, "dockmenus", false), true, "labels and menu never picked: the Dock's choice");
assert.strictEqual(lib.kwin({ dock: true, dockmenus: false }, "dockmenus", true), false, "picked: their own, whatever the Dock uses");
assert.strictEqual(lib.kwin({ dockmenus: true }, "dock", false), false, "the Dock does not follow its labels");
assert.strictEqual(lib.kwin({}, "dockmenus", true), true, "neither picked: the old switch");
assert.strictEqual(lib.tint({ dock: 0.2 }, "dockmenus"), 0.2, "no tint of their own: the Dock's");
assert.strictEqual(lib.tint({ dock: 0.2, dockmenus: 0 }, "dockmenus"), 0, "their own tint, 0 included");
assert.strictEqual(lib.tint({}, "dockmenus"), undefined, "neither has one");
console.log("ok: PanelLook.js");
