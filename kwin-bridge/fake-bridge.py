#!/usr/bin/env python3
"""fake-bridge.py: a stand-in for macshell-kwin-bridge with made-up windows, desktops, keyboard layouts and app menus.

It speaks the bridge's JSON lines (kwin-bridge/README.md), so MacShell's KWin UI (Dock, workspaces, switcher, keyboard
layouts, the global menu with a lazily filled submenu) can be exercised without KWin or before the real bridge builds:

    MACSHELL_COMPOSITOR=kwin MACSHELL_KWIN_BRIDGE="$PWD/kwin-bridge/fake-bridge.py" qs -p ./MacShell

Window actions only change the fake state; nothing happens to real windows. Commands are echoed to stderr (all data
here is made up). `fake-bridge.py --selftest` plays a scripted session against itself and checks every message;
`fake-bridge.py --validate < bridge-output` checks the real bridge's messages against the same schema (CI only: real
output contains window titles and menu labels).
"""
import json
import sys

DESKTOPS = [{"id": "{fake-desktop-%d}" % i, "name": "Desktop %d" % (i + 1), "position": i} for i in range(3)]
LAYOUTS = [{"short": "us", "display": "en", "name": "English (US)"}, {"short": "de", "display": "de", "name": "German"}]


def item(id, label="", children=None, enabled=True, separator=False, toggle="", state=0, shortcut=None, submenu=None):
    children = children or []
    return {"id": id, "label": label, "visible": True, "enabled": enabled, "separator": separator,
            "submenu": bool(children) if submenu is None else submenu, "toggle": toggle, "toggleState": state,
            "icon": "", "shortcut": shortcut or [], "children": children}


def sep(id):
    return item(id, separator=True)


def kwrite_menu():
    return [
        item(1, "File", [
            item(11, "New", shortcut=[["Control", "N"]]),
            item(12, "Open…", shortcut=[["Control", "O"]]),
            item(13, "Open Recent", submenu=True),           # filled in by AboutToShow, like real Qt apps do
            sep(14),
            item(15, "Save", shortcut=[["Control", "S"]]),
            item(16, "Save As…", shortcut=[["Control", "Shift", "S"]], enabled=False),
            sep(17),
            item(18, "Quit", shortcut=[["Control", "Q"]]),
        ]),
        item(2, "Edit", [
            item(21, "Undo", shortcut=[["Control", "Z"]], enabled=False),
            item(22, "Copy", shortcut=[["Control", "C"]]),
            item(23, "Paste", shortcut=[["Control", "V"]]),
        ]),
        item(3, "View", [
            item(31, "Show Line Numbers", toggle="checkmark", state=1, shortcut=[["F11"]]),
            item(32, "Word Wrap", toggle="checkmark", state=0),
            sep(33),
            item(34, "Zoom", [item(341, "Zoom In", shortcut=[["Control", "+"]]), item(342, "Zoom Out", shortcut=[["Control", "-"]])]),
            item(35, "Mode: Normal", toggle="radio", state=1),
            item(36, "Mode: Vi", toggle="radio", state=0),
        ]),
        item(4, "Help", [item(41, "About KWrite")]),
    ]


def dolphin_menu():
    return [item(101, "File", [item(111, "New Window", shortcut=[["Control", "N"]])]), item(102, "Go", [item(121, "Home")])]


def window(id, app, title, desktop, x, y, w, h, menu):
    return {"id": id, "appId": app, "title": title, "pid": 1000 + len(id), "resourceName": app.split(".")[-1],
            "active": False, "minimized": False, "maximized": False, "fullscreen": False, "keepAbove": False,
            "onAllDesktops": False, "demandsAttention": False, "skipTaskbar": False, "skipSwitcher": False,
            "closeable": True, "minimizeable": True, "maximizeable": True, "fullscreenable": True,
            "x": x, "y": y, "width": w, "height": h, "desktops": [DESKTOPS[desktop]["id"]], "parent": "", "hasAppMenu": menu}


class Fake:
    def __init__(self, global_menu, out):
        self.global_menu, self.out = global_menu, out
        self.windows = [
            window("{fake-kwrite}", "org.kde.kwrite", "notes.txt — KWrite", 0, 120, 90, 900, 640, True),
            window("{fake-dolphin}", "org.kde.dolphin", "Home — Dolphin", 0, 300, 160, 1000, 600, True),
            window("{fake-konsole}", "org.kde.konsole", "~ : bash — Konsole", 1, 80, 80, 800, 500, False),
            # Plasma's desktop: the UI must filter skipTaskbar windows out
            dict(window("{fake-desktop}", "org.kde.plasmashell", "Desktop", 0, 0, 0, 1920, 1080, False),
                 skipTaskbar=True, onAllDesktops=True, desktops=[]),
        ]
        self.menus = {"org.kde.kwrite": kwrite_menu(), "org.kde.dolphin": dolphin_menu()}
        self.active, self.current, self.layout, self.revision, self.showing = "{fake-kwrite}", DESKTOPS[0]["id"], 0, 1, False

    def emit(self, obj):
        self.out(json.dumps(obj, separators=(",", ":")))

    def find(self, id):
        return next((w for w in self.windows if w["id"] == id), None)

    def start(self):
        self.emit({"type": "hello", "protocol": 1, "bridge": "fake", "windowManagement": "available", "advertisedVersion": 21,
                   "appMenuProtocol": True, "globalMenu": self.global_menu, "dbus": True})
        self.emit({"type": "session", "plasmashell": True, "notifications": "other", "trayWatcher": "other",
                   "menuView": "bridge" if self.global_menu else "other"})
        self.emit({"type": "keyboard", "available": True, "current": self.layout, "layouts": LAYOUTS})
        self.emit_workspaces()
        self.emit_windows()
        self.emit_menu()

    def emit_workspaces(self):
        self.emit({"type": "workspaces", "available": True, "current": self.current, "rows": 1, "desktops": DESKTOPS})

    def emit_windows(self):
        for w in self.windows:
            w["active"] = w["id"] == self.active
        self.emit({"type": "windows", "windows": self.windows, "activeId": self.active,
                   "stacking": [w["id"] for w in self.windows], "showingDesktop": self.showing})

    def menu_items(self):
        w = self.find(self.active)
        return self.menus.get(w["appId"]) if w else None

    def emit_menu(self):
        if not self.global_menu:
            return
        w, items = self.find(self.active), self.menu_items()
        self.emit({"type": "menu", "status": "ok" if items else "none", "windowId": self.active,
                   "appId": w["appId"] if w else "", "revision": self.revision, "items": items or []})

    def menu_item(self, id, items=None):
        for it in (self.menu_items() or []) if items is None else items:
            if it["id"] == id:
                return it
            hit = self.menu_item(id, it["children"])
            if hit:
                return hit
        return None

    def handle(self, line):
        try:
            req = json.loads(line)
        except ValueError:
            return
        if not isinstance(req, dict):
            return
        cmd = req.get("cmd")
        print("fake-bridge: " + json.dumps(req), file=sys.stderr, flush=True)
        if cmd == "setDesktop" and any(d["id"] == req.get("desktop") for d in DESKTOPS):
            self.current = req["desktop"]
            here = [w for w in self.windows if self.current in w["desktops"] and not w["skipTaskbar"]]
            self.active = here[0]["id"] if here else ""      # KWin focuses a window of the new desktop
            self.emit_workspaces(); self.emit_windows(); self.emit_menu()
        elif cmd == "showDesktop":
            self.showing = bool(req.get("on")); self.emit_windows()
        elif cmd == "setKeyboardLayout" and isinstance(req.get("index"), int) and 0 <= req["index"] < len(LAYOUTS):
            self.layout = req["index"]
            self.emit({"type": "keyboard", "available": True, "current": self.layout, "layouts": LAYOUTS})
        elif cmd in ("menuEvent", "menuAboutToShow"):
            it = self.menu_item(req.get("id"))
            if req.get("windowId") != self.active or not it:
                return                                           # stale or unknown: dropped, like the real bridge
            if cmd == "menuAboutToShow" and it["id"] == 13 and not it["children"]:
                it["children"] = [item(131, "todo.md"), item(132, "notes.txt")]
                self.revision += 1; self.emit_menu()
            elif cmd == "menuEvent" and req.get("event") == "clicked" and it["toggle"] and it["enabled"] and not it["submenu"]:
                if it["toggle"] == "radio":
                    for sib in (self.menu_item(3) or {}).get("children", []):
                        if sib["toggle"] == "radio":
                            sib["toggleState"] = 0
                    it["toggleState"] = 1
                else:
                    it["toggleState"] = 0 if it["toggleState"] else 1
                self.revision += 1; self.emit_menu()
        else:
            w = self.find(req.get("id"))
            if not w:
                return
            if cmd == "activate":
                self.active, w["minimized"] = w["id"], False
                if w["desktops"] and self.current not in w["desktops"]:
                    self.current = w["desktops"][0]; self.emit_workspaces()
            elif cmd == "close":
                self.windows.remove(w)
                if self.active == w["id"]:
                    self.active = next((x["id"] for x in self.windows if not x["skipTaskbar"]), "")
            elif cmd in ("minimize", "unminimize", "toggleMinimize"):
                w["minimized"] = {"minimize": True, "unminimize": False}.get(cmd, not w["minimized"])
                if w["minimized"] and self.active == w["id"]:
                    self.active = ""
            elif cmd == "toggleMaximize":
                w["maximized"] = not w["maximized"]
            elif cmd == "toggleFullscreen":
                w["fullscreen"] = not w["fullscreen"]
            elif cmd == "toggleKeepAbove":
                w["keepAbove"] = not w["keepAbove"]
            elif cmd == "moveToDesktop" and any(d["id"] == req.get("desktop") for d in DESKTOPS):
                w["desktops"] = [req["desktop"]]
            else:
                return
            self.emit_windows(); self.emit_menu()


# message type → keys every message of that type carries (kwin-bridge/README.md "Messages")
SCHEMA = {
    "hello": {"protocol", "bridge", "windowManagement", "advertisedVersion", "appMenuProtocol", "globalMenu", "dbus"},
    "windows": {"windows", "activeId", "stacking", "showingDesktop"},
    "workspaces": {"available", "current", "rows", "desktops"},
    "keyboard": {"available", "current", "layouts"},
    "menu": {"status", "windowId", "appId", "revision", "items"},
    "session": {"plasmashell", "notifications", "trayWatcher", "menuView"},
}
WINDOW_KEYS = {"id", "appId", "title", "pid", "resourceName", "active", "minimized", "maximized", "fullscreen", "keepAbove",
               "onAllDesktops", "demandsAttention", "skipTaskbar", "skipSwitcher", "closeable", "minimizeable",
               "maximizeable", "fullscreenable", "x", "y", "width", "height", "desktops", "parent", "hasAppMenu"}
ITEM_KEYS = {"id", "label", "visible", "enabled", "separator", "submenu", "toggle", "toggleState", "icon", "shortcut", "children"}


def check(msg):
    missing = SCHEMA[msg["type"]] - msg.keys()
    assert not missing, (msg["type"], missing)
    for w in msg.get("windows", []):
        assert not (WINDOW_KEYS - w.keys()), WINDOW_KEYS - w.keys()

    def items(xs):
        for x in xs:
            assert not (ITEM_KEYS - x.keys()), ITEM_KEYS - x.keys()
            items(x["children"])
    items(msg.get("items", []))


def selftest():
    sent = []
    fake = Fake(True, lambda s: sent.append(json.loads(s)))
    fake.start()
    last = lambda t: [m for m in sent if m["type"] == t][-1]
    assert last("menu")["status"] == "ok" and last("menu")["windowId"] == "{fake-kwrite}"
    fake.handle('{"cmd":"menuAboutToShow","windowId":"{fake-kwrite}","id":13}')
    assert [c["label"] for c in fake.menu_item(13)["children"]] == ["todo.md", "notes.txt"]
    fake.handle('{"cmd":"menuEvent","windowId":"{fake-kwrite}","id":31,"event":"clicked"}')
    assert fake.menu_item(31)["toggleState"] == 0
    fake.handle('{"cmd":"menuEvent","windowId":"{stale}","id":32,"event":"clicked"}')
    assert fake.menu_item(32)["toggleState"] == 0                       # stale window: dropped
    fake.handle('{"cmd":"activate","id":"{fake-konsole}"}')
    assert last("windows")["activeId"] == "{fake-konsole}" and last("workspaces")["current"] == DESKTOPS[1]["id"]
    assert last("menu")["status"] == "none"                             # Konsole exports no menu: generic menus
    fake.handle('{"cmd":"setKeyboardLayout","index":1}')
    assert last("keyboard")["current"] == 1
    fake.handle('{"cmd":"close","id":"{fake-konsole}"}')
    assert all(w["id"] != "{fake-konsole}" for w in last("windows")["windows"])
    fake.handle('not json'); fake.handle('{"cmd":"activate","id":"{nope}"}')  # ignored
    for m in sent:
        check(m)
    print("fake-bridge selftest: %d messages ok" % len(sent))


def validate(lines):
    counts = {}
    for line in lines:
        if line.strip():
            msg = json.loads(line)
            check(msg)
            counts[msg["type"]] = counts.get(msg["type"], 0) + 1
    assert counts.get("hello") == 1, counts
    print("bridge output matches the protocol: " + " ".join("%s=%d" % kv for kv in sorted(counts.items())))


def main(argv):
    flags = set(argv[1:])
    if flags - {"--global-menu", "--check", "--version", "--selftest", "--validate"}:
        print("usage: fake-bridge.py [--global-menu] [--check] [--version] [--selftest] [--validate]", file=sys.stderr)
        return 2
    if "--selftest" in flags:
        selftest(); return 0
    if "--validate" in flags:
        validate(sys.stdin); return 0
    if "--version" in flags:
        print("macshell-kwin-bridge fake (protocol 1)"); return 0
    if "--check" in flags:
        print("status=ok window_management=available advertised_version=21 windows=3 (fake)"); return 0
    fake = Fake("--global-menu" in flags, lambda s: print(s, flush=True))
    fake.start()
    for line in sys.stdin:                                       # EOF: MacShell went away
        fake.handle(line)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
