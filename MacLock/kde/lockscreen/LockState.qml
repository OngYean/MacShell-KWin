// The lock state every screen shares: what ../../shell.qml's lockState is on Hyprland. KDE creates one view per
// screen in one QML engine, and a singleton is the one object they all see (KDE's own PasswordSync works the same).
// The password is checked by KDE's `authenticator` (PAM service "kde", fingerprint and smartcard included), which
// LockScreen.qml hands over in attach(): KDE lets this screen quit only after that authenticator has succeeded.
pragma Singleton
import QtQuick
import "ui"

Item {
    id: st

    // ── what ui/LockScreen.qml reads and writes (same names as ../../shell.qml)
    property var now: new Date()
    property string wallpaper: ""
    property string wallpaperVideo: ""
    property string userName: ""
    property string avatar: ""
    property int wifiLevel: -1          // -1 unknown/hidden, 0 off, 1..3 bars
    property bool ethernet: false
    property string pass: ""
    property bool busy: false
    property int fails: 0
    property string message: ""
    property bool engaged: false
    property bool unlocking: false
    property string mediaSlot: "top"
    property bool use24h: true
    property var clockCfg: ({})
    property bool artBg: true
    property bool sounds: false
    property string npMode: ""
    property string mainScreen: ""      // MacShell's Settings → Displays → Main display ("" = never chosen)
    readonly property bool capsLock: capsKey ? capsKey.locked : false

    function poke() { engaged = true; idleTimer.restart(); }
    function checkCaps() { }            // asked for after a Caps Lock press; KDE's key state updates by itself
    function sound(name) { if (sounds) tool.detached(["sh", "-c", 'pw-play --volume=0.7 "$HOME/.local/share/sounds/macshell/$1.wav"', "sh", name]); }
    function setMediaSlot(v) {
        if (v === mediaSlot) return;
        mediaSlot = v;
        tool.detached(["sh", "-c", 'mkdir -p "$HOME/.config/maclock" && printf \'{\\n  "mediaSlot": "%s"\\n}\\n\' "$1" > "$HOME/.config/maclock/settings.json"', "sh", v]);
    }
    function fail(msg) { pass = ""; message = msg; fails++; msgTimer.restart(); }
    // The screen that gets the full layout, of the connected ones (objects with a name): the Main display chosen in
    // MacShell while it is connected, else the built-in panel, else the first.
    function primaryOf(screens) {
        var i;
        for (i = 0; i < screens.length; i++) if (mainScreen !== "" && screens[i].name === mainScreen) return mainScreen;
        for (i = 0; i < screens.length; i++) if (/^(eDP|LVDS|DSI)/i.test(screens[i].name)) return screens[i].name;
        return screens.length > 0 ? screens[0].name : "";
    }
    function unlock() { unlocking = true; sound("unlock"); unlockTimer.start(); }

    // ── password check
    property var auth: null             // KDE's authenticator
    property bool asked: false          // PAM is waiting for an answer
    property string held: ""            // typed before PAM asked: sent when it does (an answer to no question is dropped)
    property bool open: false           // PAM let the user in without asking (no password set): Enter unlocks

    function attach(authenticator, name, image) {
        if (auth) return;               // every screen's view calls this
        auth = authenticator;
        userName = name || "";
        avatar = image || "";
    }
    function submit() {
        if (busy || unlocking) return;
        if (open) { unlock(); return; }
        if (pass.length === 0 || !auth) return;
        busy = true;
        message = "";
        stuck.restart();
        if (asked) answer(pass);
        else { held = pass; auth.startAuthenticating(); }
    }
    function answer(text) { asked = false; held = ""; auth.respond(text); }
    function asking() {
        asked = true;
        if (held !== "") answer(held);
    }
    Connections {
        target: st.auth
        function onPromptForSecretChanged() { if (st.auth.promptForSecret !== "") st.asking(); }
        function onPromptChanged() { if (st.auth.prompt !== "") st.asking(); }
        function onInfoMessageChanged() { if (st.auth.infoMessage !== "") { st.message = st.auth.infoMessage; msgTimer.restart(); } }
        function onErrorMessageChanged() { if (st.auth.errorMessage !== "") { st.message = st.auth.errorMessage; msgTimer.restart(); } }
        function onFailed(kind) {
            if (kind != 0) return;      // fingerprint, smartcard, …: they retry by themselves
            st.asked = false; st.held = "";
            stuck.stop();
            // only a password the user sent counts as wrong: PAM also gives up by itself after a long wait
            if (st.busy) { st.busy = false; st.fail("Incorrect password"); }
            if (st.engaged) st.auth.startAuthenticating();
        }
        function onSucceeded() {
            st.auth.stopAuthenticating();       // as KDE's own screen does: ends the other pending checks
            stuck.stop();
            st.busy = false;
            if (st.auth.hadPrompt) st.unlock();
            else st.open = true;
        }
    }
    onEngagedChanged: if (engaged && auth && !open && !unlocking) auth.startAuthenticating()
    // KDE's own screen does the same once a second while it is in use: restarts whatever check has ended
    Timer { interval: 1000; repeat: true; running: st.engaged && st.auth !== null && !st.open && !st.unlocking; onTriggered: st.auth.startAuthenticating() }
    // PAM never answered: let the user type again instead of ignoring the keyboard forever
    Timer { id: stuck; interval: 20000; onTriggered: { st.busy = false; st.held = ""; st.fail("Authentication error"); } }

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: st.now = new Date() }
    Timer { id: idleTimer; interval: 9000; onTriggered: if (st.pass.length === 0 && !st.busy) st.engaged = false }
    Timer { id: msgTimer; interval: 3500; onTriggered: st.message = "" }
    // let the exit animation play, then quit: KDE drops the lock when this process exits after a successful check
    Timer { id: unlockTimer; interval: 430; onTriggered: Qt.quit() }

    // ── Caps Lock: a private Plasma module, so created at run time and simply absent if it will not load
    property var capsKey: null
    Component.onCompleted: {
        try {
            capsKey = Qt.createQmlObject('import QtQuick; import org.kde.plasma.private.keyboardindicator as KI; KI.KeyState { key: Qt.Key_CapsLock }', st);
        } catch (e) {
            console.warn("[maclock] no Caps Lock indicator:", e);
        }
        lookup.run(["sh", "-c", lookupScript]);
    }

    // ── one-shot lookups: MacShell's settings, the wallpaper, the network (no jq: the JSON is parsed here)
    Run { id: tool }
    readonly property string mark: "@@maclock@@"
    readonly property string lookupScript: [
        'm() { printf "\\n%s\\n" "' + mark + '"; }',
        'cat "$HOME/.config/macbar/settings.json" 2>/dev/null; m',
        'cat "$HOME/.config/macdock/settings.json" 2>/dev/null; m',
        'cat "$HOME/.config/maclock/settings.json" 2>/dev/null; m',
        'cat "$HOME/.config/macshell/wallpaper-video-play" 2>/dev/null; m',
        'cat "$HOME/.config/macshell/wallpaper-video" 2>/dev/null; m',
        '[ -f "${XDG_RUNTIME_DIR:-/tmp}/macshell-gaming.state" ] && echo gaming; m',
        'if [ "$(nmcli radio wifi 2>/dev/null)" = enabled ]; then s=$(nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | grep "^yes" | head -n1 | cut -d: -f2); echo "${s:-0}"; else echo -1; fi; m',
        'nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q "^ethernet:connected$" && echo eth; m',
        'cat "$HOME/.config/macshell/displays.json" 2>/dev/null'
    ].join("\n")
    function json(text) { try { return JSON.parse(text) || {}; } catch (e) { return {}; } }
    Run {
        id: lookup
        onDone: out => {
            var part = out.split("\n" + st.mark + "\n").map(function (p) { return p.trim(); });
            var bar = st.json(part[0] || ""), dock = st.json(part[1] || ""), lock = st.json(part[2] || "");
            st.mediaSlot = lock.mediaSlot === "bottom" ? "bottom" : "top";
            st.sounds = bar.uiSounds !== false && (part[5] || "") !== "gaming";
            st.artBg = bar.lockArtBackground !== false;
            st.use24h = bar.use24h !== false;
            Qt.uiLanguage = (!bar.language || bar.language === "auto") ? "" : bar.language;
            st.clockCfg = { f: bar.lockClockFont, w: bar.lockClockWeight, m: bar.lockClockMaterial, d: bar.lockClockDate, i: bar.lockClockIntensity, c: bar.lockClockTint };
            var s = parseInt(part[6] || "-1");
            st.wifiLevel = isNaN(s) || s < 0 ? -1 : (s === 0 ? 0 : (s > 66 ? 3 : (s > 33 ? 2 : 1)));
            st.ethernet = (part[7] || "") === "eth";
            st.mainScreen = String(st.json(part[8] || "").primary || "");
            st.sound("lock");
            // the wallpaper MacShell draws, and its video if one is set; only files that exist
            files.want = [bar.wallpaperPath || "", dock.wallpaperPath || "", part[3] || "", part[4] || ""];
            files.run(["sh", "-c", 'for f in "$@"; do [ -f "$f" ] && echo y || echo n; done', "sh"].concat(files.want));
        }
    }
    Run {
        id: files
        property var want: []
        onDone: out => {
            var have = out.split("\n"), w = want;
            st.wallpaper = have[0] === "y" ? w[0] : (have[1] === "y" ? w[1] : "");
            st.wallpaperVideo = w[3] === "" ? "" : (have[2] === "y" ? w[2] : (have[3] === "y" ? w[3] : ""));
        }
    }
}
