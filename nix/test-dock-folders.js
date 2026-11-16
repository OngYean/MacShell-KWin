// test-dock-folders.js — checks the folders pinned to the Dock: MacShell/DockFolders.js (the pin list and the stack's
// tiles) and MacShell/assets/list-folder.sh (the listing a click on a folder runs), on a folder made for the test.
//   node nix/test-dock-folders.js          (no Qt, Plasma or Nix needed)
const fs = require("fs"), os = require("os"), path = require("path"), vm = require("vm"), assert = require("assert");
const { execFileSync } = require("child_process");
const src = fs.readFileSync(path.join(__dirname, "../MacShell/DockFolders.js"), "utf8").replace(/^\.pragma .*$/m, "");
const lib = {};
vm.runInNewContext(src + "\nout.isDir = isDir; out.norm = norm; out.name = name; out.add = add; out.remove = remove; out.tiles = tiles;", { out: lib });
const plain = v => JSON.parse(JSON.stringify(v));      // out of the vm's realm, for deepStrictEqual

// ── the pin list: app ids and folders side by side ──
assert.strictEqual(lib.isDir("/home/u/Downloads"), true);
assert.strictEqual(lib.isDir("org.kde.dolphin"), false);
assert.strictEqual(lib.isDir("__apps"), false);
assert.strictEqual(lib.norm("/home/u/Downloads/"), "/home/u/Downloads", "trailing slash dropped");
assert.strictEqual(lib.norm("  /home/u/My Files\n"), "/home/u/My Files", "the picker's newline dropped, spaces inside kept");
assert.strictEqual(lib.norm("/"), "/");
assert.strictEqual(lib.norm("Downloads"), "", "a relative path is not pinned");
assert.strictEqual(lib.norm(""), "", "a cancelled picker pins nothing");
assert.strictEqual(lib.norm(undefined), "");
assert.strictEqual(lib.name("/home/u/Downloads"), "Downloads");
assert.strictEqual(lib.name("/"), "/");

const pins = ["firefox", "__apps"];
assert.deepStrictEqual(plain(lib.add(pins, "/home/u/Downloads/")), ["firefox", "__apps", "/home/u/Downloads"]);
assert.deepStrictEqual(pins, ["firefox", "__apps"], "the list handed in is not changed");
assert.strictEqual(lib.add(["firefox", "/home/u/Downloads"], "/home/u/Downloads/"), null, "already pinned");
assert.strictEqual(lib.add(pins, ""), null);
assert.deepStrictEqual(plain(lib.remove(["firefox", "/a", "/b"], "/a")), ["firefox", "/b"], "apps and other folders stay");

// ── the tiles, from a listing ──
const t = plain(lib.tiles("inode/directory\tsub\napplication/pdf\ta b#1?.pdf\nimage/png\tpic.png\nimage/heic\tp.heic\n\ttab\tname\n\n", "/d"));
assert.deepStrictEqual(t.map(x => x.name), ["sub", "a b#1?.pdf", "pic.png", "p.heic", "tab\tname"]);
assert.deepStrictEqual(t.map(x => x.icon), ["folder", "application-pdf", "image-png", "image-heic", "text-x-generic"]);
assert.strictEqual(t[0].isDir, true);
assert.strictEqual(t[1].path, "/d/a b#1?.pdf");
assert.strictEqual(t[2].thumb, "file:///d/pic.png", "a picture Qt reads is its own icon");
assert.strictEqual(t[3].thumb, "", "one it may not read keeps the type's icon");
assert.strictEqual(plain(lib.tiles("image/png\ta b#1?.png\n", "/d"))[0].thumb, "file:///d/a%20b%231%3F.png", "URL-escaped");
assert.strictEqual(plain(lib.tiles("text/plain\tx\n", "/"))[0].path, "/x", "a child of /");
assert.strictEqual(plain(lib.tiles("application/x-desktop\tApp.desktop\n", "/d"))[0].isApp, true);
assert.deepStrictEqual(plain(lib.tiles("", "/d")), [], "an empty folder");

// ── the listing script, on a real folder ──
const script = path.join(__dirname, "../MacShell/assets/list-folder.sh");
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "dock-folders-"));
try {
    const at = (n, age) => fs.utimesSync(path.join(dir, n), Date.now() / 1000 - age, Date.now() / 1000 - age);
    fs.writeFileSync(path.join(dir, "old.txt"), "old\n"); at("old.txt", 300);
    fs.mkdirSync(path.join(dir, "sub dir")); at("sub dir", 200);
    fs.writeFileSync(path.join(dir, "-new file.txt"), "new\n"); at("-new file.txt", 100);
    fs.writeFileSync(path.join(dir, ".hidden"), "x\n");
    const run = (...a) => execFileSync("sh", [script, ...a], { encoding: "utf8" });
    const all = plain(lib.tiles(run(dir, "15"), dir));
    assert.deepStrictEqual(all.map(x => x.name), ["-new file.txt", "sub dir", "old.txt"], "newest first, hidden files left out");
    assert.strictEqual(all[1].isDir, true);
    assert.strictEqual(all[1].icon, "folder");
    assert.ok(["text-plain", "text-x-generic"].includes(all[0].icon), "the type's icon, or the generic one without `file`: " + all[0].icon);
    assert.strictEqual(plain(lib.tiles(run(dir, "2"), dir)).length, 2, "no more than asked for");
    assert.strictEqual(run(path.join(dir, "gone"), "15"), "", "a folder that no longer exists lists nothing");
} finally {
    fs.rmSync(dir, { recursive: true, force: true });
}

console.log("test-dock-folders: ok");
