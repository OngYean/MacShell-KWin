.pragma library

// Folders pinned to the Dock (they sit left of the Trash and open as a stack). They live in the Dock's pin list
// (~/.config/macdock/pinned.json) beside the app ids: an entry that starts with "/" is a folder.

function isDir(entry) { return String(entry).charAt(0) === "/"; }

// an absolute path without trailing slashes, or "" when it is not an absolute path
function norm(p) {
    p = String(p === undefined || p === null ? "" : p).trim();
    if (p.charAt(0) !== "/") return "";
    return p.replace(/\/+$/, "") || "/";
}

function name(path) { return path === "/" ? "/" : path.slice(path.lastIndexOf("/") + 1); }

// the pin list with the folder added at the end, or null when there is nothing to change (not a path, already pinned)
function add(pinned, path) {
    var p = norm(path);
    if (p === "" || pinned.indexOf(p) >= 0) return null;
    return pinned.concat([p]);
}

function remove(pinned, path) { return pinned.filter(function (e) { return e !== path; }); }

function fileUrl(path) { return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F"); }

// The stack's listing script prints "mime type<TAB>file name" per child (the type is empty when `file` is missing).
// -> [{ name, path, isDir, isApp, icon, thumb }]: icon is a theme icon name (the freedesktop name of the type),
// thumb the picture itself for the image types Qt reads.
function tiles(text, dir) {
    var out = [], ls = String(text).split("\n");
    for (var i = 0; i < ls.length; i++) {
        var t = ls[i].indexOf("\t");
        if (t < 0 || t === ls[i].length - 1) continue;
        var mime = ls[i].slice(0, t), n = ls[i].slice(t + 1), path = (dir === "/" ? "" : dir) + "/" + n;
        var d = mime === "inode/directory";
        out.push({ name: n, path: path, isDir: d, isApp: !d && /\.desktop$/i.test(n),
                   icon: d ? "folder" : (mime !== "" ? mime.replace(/\//g, "-") : "text-x-generic"),
                   thumb: /^image\/(png|jpeg|gif|webp|bmp|svg\+xml)$/.test(mime) ? fileUrl(path) : "" });
    }
    return out;
}
