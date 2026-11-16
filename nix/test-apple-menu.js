// test-apple-menu.js — checks MacShell/AppleMenu.js: the list behind the top-left menu (its defaults, what a saved list
// is cleaned to, arranging it, and what is left out when it is shown).
//   node nix/test-apple-menu.js            (no Qt, Plasma or Nix needed)
const fs = require("fs"), path = require("path"), vm = require("vm"), assert = require("assert");
const src = fs.readFileSync(path.join(__dirname, "../MacShell/AppleMenu.js"), "utf8").replace(/^\.pragma .*$/m, "");
const lib = {};
vm.runInNewContext(src + "\nfor (const k of ['builtin','names','entry','defaults','clean','missing','move','remove','add','set','shown','pushRecent']) out[k] = eval(k);", { out: lib });
const plain = v => JSON.parse(JSON.stringify(v));      // out of the vm's realm, for deepStrictEqual
const ids = l => plain(l).map(e => e.id);
const E = (id, label = "", command = "") => ({ id, label, command });

// ── defaults: the original menu's items in macOS order, plus Recent Items and Force Quit ──
const d = lib.defaults();
assert.deepStrictEqual(ids(d), ["about", "sep", "settings", "sep", "recent", "sep", "forcequit", "sep", "sleep", "restart", "shutdown", "sep", "lock", "logout"]);
assert.deepStrictEqual(plain(lib.missing(d)), [], "every built-in item is in the default menu");
for (const id of lib.builtin) assert.ok(lib.names[id], "a name for " + id);

// ── clean: what was saved, or typed by hand ──
assert.deepStrictEqual(ids(lib.clean(undefined)), ids(d), "never saved: the defaults");
assert.deepStrictEqual(ids(lib.clean("about")), ids(d), "not a list: the defaults");
assert.deepStrictEqual(plain(lib.clean([])), [], "an empty list stays empty (every item removed on purpose)");
assert.deepStrictEqual(plain(lib.clean([E("sleep"), null, "lock", { id: 3 }, E("bogus"), E("sleep"), E("sep"), E("sep")])),
    [E("sleep"), E("sep"), E("sep")], "junk and unknown ids dropped, a built-in item once, separators as often as wanted");
assert.deepStrictEqual(plain(lib.clean([{ id: "custom", label: "Htop", command: "kitty -e htop", extra: 1 }, { id: "lock", label: "x", command: 7 }, { id: "sep", command: "rm" }])),
    [E("custom", "Htop", "kitty -e htop"), E("lock"), E("sep")], "only the three fields, a label on custom items only, a command never on a separator");

// ── arranging ──
const l = [E("about"), E("sep"), E("lock")];
assert.deepStrictEqual(ids(lib.move(l, 2, -1)), ["about", "lock", "sep"], "up");
assert.deepStrictEqual(ids(lib.move(l, 0, 1)), ["sep", "about", "lock"], "down");
assert.deepStrictEqual(ids(lib.move(l, 0, -1)), ["about", "sep", "lock"], "the first stays first");
assert.deepStrictEqual(ids(lib.move(l, 2, 1)), ["about", "sep", "lock"], "the last stays last");
assert.deepStrictEqual(ids(lib.remove(l, 1)), ["about", "lock"]);
assert.deepStrictEqual(plain(lib.add(l, "custom"))[3], E("custom", "New Item"), "a new custom item has a name, so it shows");
assert.deepStrictEqual(plain(lib.add(l, "sleep"))[3], E("sleep"));
assert.deepStrictEqual(plain(lib.set(l, 2, "command", "loginctl lock-session"))[2], E("lock", "", "loginctl lock-session"));
assert.deepStrictEqual(plain(l), [E("about"), E("sep"), E("lock")], "none of them changes the list handed in");
assert.deepStrictEqual(plain(lib.missing(l)), ["settings", "recent", "forcequit", "sleep", "restart", "shutdown", "logout"]);

// ── what is shown ──
assert.deepStrictEqual(ids(lib.shown([E("sep"), E("about"), E("sep"), E("sep"), E("custom", " "), E("sep"), E("lock"), E("sep")])),
    ["about", "sep", "lock"], "no separator first, last or twice in a row; a custom item without a name is skipped");
assert.deepStrictEqual(plain(lib.shown([E("sep")])), []);
assert.deepStrictEqual(plain(lib.entry("settings")), E("settings"), "what MacBar.qml falls back to when nothing is shown");

// ── recent applications ──
assert.deepStrictEqual(plain(lib.pushRecent(["a", "b", "c"], "b", 3)), ["b", "a", "c"], "started again: to the front, once");
assert.deepStrictEqual(plain(lib.pushRecent(["a", "b", "c"], "d", 3)), ["d", "a", "b"], "the oldest falls off");

console.log("ok: AppleMenu.js");

// ── the rows MacBar.qml builds from the list: its three functions, lifted out of the QML, with stand-ins around them ──
const qml = fs.readFileSync(path.join(__dirname, "../MacShell/MacBar.qml"), "utf8");
const fn = name => { const m = qml.match(new RegExp("^    function " + name + "\\([^)]*\\) \\{$[\\s\\S]*?^    \\}$", "m")); assert.ok(m, name + " not found in MacBar.qml"); return m[0]; };
const ran = [];
const ctx = {
    AppleMenu: lib, I18n: { tr: t => t }, ran,
    msep: () => ({ kind: "sep" }), ico: (item, g) => { item.glyph = g; return item; },
    sh: c => ran.push("sh " + c), openPath: p => ran.push("open " + p), lockScreen: () => ran.push("lock"),
    lookup: cls => (cls === "firefox" ? { name: "Firefox", icon: "firefox" } : null), iconSrc: n => "icon:" + n,
    appRunner: e => () => ran.push("launch " + e.id),
    DesktopEntries: { byId: id => (id === "gone" ? null : { id, name: id.toUpperCase(), icon: id }) },
    Quickshell: { execDetached: a => ran.push(a.join(" ")) },
    onHyprland: false, hub: null, terminal: "kitty",
    comp: { clients: [{ class: "firefox", pid: 10 }, { class: "firefox", pid: 11 }, { class: "Firefox", pid: 10 }, { class: "org.quickshell", pid: 5 }, { class: "nopid", pid: 0 }, { class: "org.kde.kate", pid: 20 }] },
    recentApps: ["kate", "gone", "firefox"], recentLoading: false,
    recentHits: [{ kind: "d", path: "/home/u/Dir" }, { kind: "f", path: "/home/u/a b.pdf" }, { kind: "f", path: "/home/u/c.txt" }],
};
ctx.root = ctx;
vm.createContext(ctx);
vm.runInContext([fn("appleItem"), fn("runningApps"), fn("appleSubModel")].join("\n"), ctx);
const row = e => vm.runInContext("appleItem(" + JSON.stringify(e) + ")", ctx);

assert.strictEqual(row(E("sep")).kind, "sep");
let r = row(E("lock"));
assert.deepStrictEqual([r.label, r.glyph, r.raw, r.confirm, r.asub], ["Lock Screen", "m_lock", false, undefined, undefined]);
r.run(); assert.strictEqual(ran.pop(), "lock", "a built-in item does its own thing");
r = row(E("lock", "", " loginctl lock-session "));
r.run(); assert.strictEqual(ran.pop(), "sh loginctl lock-session", "a command on a built-in item runs instead");
r = row(E("shutdown", "", "systemctl poweroff"));
assert.strictEqual(r.confirm, true, "Shut Down still asks for a second click with a custom command");
r = row(E("recent"));
assert.deepStrictEqual([r.asub, r.shortcut, r.run], ["recent", "›", undefined], "Recent Items opens its list inside the popover");
r = row(E("forcequit", "", "plasma-systemmonitor"));
assert.deepStrictEqual([r.asub, r.shortcut], [undefined, ""], "with a command, Force Quit is a plain item");
r.run(); assert.strictEqual(ran.pop(), "sh plasma-systemmonitor");
r = row(E("custom", "Htop", "kitty -e htop"));
assert.deepStrictEqual([r.label, r.raw], ["Htop", true], "a custom item's name is shown as typed, not translated");
r.run(); assert.strictEqual(ran.pop(), "sh kitty -e htop");

const apps = plain(vm.runInContext("runningApps()", ctx));
assert.deepStrictEqual(apps, [{ name: "Firefox", icon: "icon:firefox", pids: [10, 11] }, { name: "org.kde.kate", icon: "", pids: [20] }],
    "one row per app with the processes of all its windows; MacShell's own windows and windows without a pid are left out");

let sub = vm.runInContext("appleSubModel('forcequit')", ctx);
assert.deepStrictEqual([sub[0].back, sub[0].label, sub[1].kind], [true, "‹  Force Quit", "sep"], "a back row first");
assert.deepStrictEqual(plain(sub.slice(2).map(x => [x.label, x.confirm])), [["Firefox", true], ["org.kde.kate", true]], "every app needs a second click");
sub[2].run(); assert.strictEqual(ran.pop(), "kill -9 10 11");

sub = vm.runInContext("appleSubModel('recent')", ctx);
assert.deepStrictEqual(plain(sub.map(x => x.kind === "sep" ? "-" : x.label + (x.disabled ? " (off)" : ""))),
    ["‹  Recent Items", "-", "Applications (off)", "KATE", "FIREFOX", "-", "Documents (off)", "a b.pdf", "c.txt"],
    "applications that still exist, then files (folders are not documents)");
sub[3].run(); assert.strictEqual(ran.pop(), "launch kate");
sub[7].run(); assert.strictEqual(ran.pop(), "open /home/u/a b.pdf");
ctx.recentApps = "junk"; ctx.recentHits = []; ctx.recentLoading = true;
sub = vm.runInContext("appleSubModel('recent')", ctx);
assert.deepStrictEqual(plain(sub.slice(2).map(x => x.kind === "sep" ? "-" : x.label)), ["Applications", "None", "-", "Documents", "Loading…"], "nothing to list yet");
ctx.comp = { clients: [] };
assert.strictEqual(vm.runInContext("appleSubModel('forcequit')", ctx)[2].label, "No open applications");

console.log("ok: the Apple menu's rows in MacBar.qml");
