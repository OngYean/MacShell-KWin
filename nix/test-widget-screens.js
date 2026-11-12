// test-widget-screens.js — checks the per-screen widget grid in MacShell/MacWidgets.qml: its top-level functions are
// plain JavaScript, so they are lifted out of the QML and run against a stand-in model and two stand-in screens.
//   node nix/test-widget-screens.js        (no Qt, Plasma or Nix needed)
const fs = require("fs"), path = require("path"), vm = require("vm"), assert = require("assert");
const qml = fs.readFileSync(path.join(__dirname, "../MacShell/MacWidgets.qml"), "utf8");
const fns = qml.match(/^ {4}function \w+\([^)]*\) \{(?:.*\}$|(?:\s*\/\/.*)?$[\s\S]*?^ {4}\}$)/gm).join("\n");

const rows = [];
const ctx = {
    Quickshell: { screens: [{ name: "A", x: 0, y: 0, width: 1920, height: 1080 }, { name: "B", x: 1920, y: 0, width: 1280, height: 720 }] },
    wmodel: { get count() { return rows.length; }, get: i => rows[i], append: o => rows.push(o), setProperty: (i, k, v) => { rows[i][k] = v; } },
    hub: { compositor: { focusedScreenName: "A" } },
    widgetScale: 1, gridCell: 179, gridGapX: 28, gridGapY: 23, gridLeft: 21, gridTop: 56, gridRight: 21, gridBottom: 24,
    rev: 0, anyLiquid: false, ready: false, Date, Math, Infinity
};
vm.runInNewContext(fns + "\nrefreshSoon = function () {};", ctx);
const on = scr => rows.filter(r => ctx.scrOf(r.wscreen) === scr);

assert.ok(ctx.addWidget("clock", "liquid", "small"), "a widget is added");
assert.strictEqual(rows[0].wscreen, "A", "it goes on the screen in use");
ctx.hub.compositor.focusedScreenName = "B";
assert.ok(ctx.addWidget("player", "liquid", "small"), "a widget is added on the other screen");
assert.strictEqual(rows[1].wscreen, "B", "the other screen takes it");
assert.ok(rows[1].wx + 185 <= 1280 - 21, "placed inside the smaller screen");

rows.push({ wid: "old", wtype: "player", wstyle: "liquid", wsize: "small", wmode: "auto", wsrc: "", wscreen: "", wx: rows[1].wx, wy: rows[1].wy });
assert.strictEqual(on("A").length, 2, "a widget saved without a screen is on the first screen");
assert.strictEqual(ctx.overlaps(rows[1].wx, rows[1].wy, [185, 185], "", "B"), true, "its own screen's slot is taken");
assert.strictEqual(ctx.overlaps(rows[1].wx, rows[1].wy, [185, 185], rows[1].wid, "B"), false, "the same spot on another screen does not block");

assert.strictEqual(ctx.pr(0, 0, "B"), rows[1].wx, "Player rectangles are per screen (B)");
assert.strictEqual(ctx.pr(0, 2, "A"), 185, "Player rectangles are per screen (A)");
assert.strictEqual(ctx.pr(1, 2, "A"), 0, "no second Player on A");

ctx.moveWidget(rows[0].wid, 30, 60, "B");                        // dropped on screen B
assert.strictEqual(rows[0].wscreen, "B", "a dropped widget changes screen");
assert.ok(rows[0].wx !== rows[1].wx || rows[0].wy !== rows[1].wy, "and snaps to a free slot there");
assert.strictEqual(ctx.countOn("A"), 1, "one widget left on A");

ctx.Quickshell.screens.pop();                                    // B unplugged
const kept = [rows[0].wx, rows[0].wy];
ctx.normalizePositions();
assert.deepStrictEqual([rows[0].wx, rows[0].wy], kept, "widgets of an unplugged screen keep their place");
assert.strictEqual(ctx.targetScreen(), "A", "a screen that is gone is not a target");
console.log("ok: MacWidgets.qml per-screen grid");
