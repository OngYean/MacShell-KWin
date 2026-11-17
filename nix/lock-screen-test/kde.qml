// Loads MacLock the way KDE's lock screen does (nix/test-lock-screen.sh puts this file next to the assembled
// package) and walks the password flow against a stand-in for KDE's authenticator. Exits 0 through the lock
// screen's own Qt.quit() after a successful unlock, non-zero on the first failed check.
import QtQuick
import "com.macshell.lock/contents/lockscreen" as Lock

Item {
    id: t
    width: 1280; height: 800

    // what kscreenlocker hands the lock screen
    property string kscreenlocker_userName: "Test User"
    property string kscreenlocker_userImage: ""
    property QtObject authenticator: QtObject {
        property string prompt: ""
        property string promptForSecret: ""
        property string infoMessage: ""
        property string errorMessage: ""
        property bool hadPrompt: false
        property int starts: 0
        property var answers: []
        signal failed(int kind, var who)
        signal succeeded()
        function startAuthenticating() { starts++; }
        function stopAuthenticating() { }
        function respond(text) { answers.push(String(text)); }
    }

    Lock.LockScreen { id: view; anchors.fill: parent }
    readonly property Item ui: view.children[0]      // ui/LockScreen.qml, the one visual child

    property int bad: 0
    function check(what, ok) {
        if (ok) return;
        bad++;
        console.error("lock-screen-test: FAIL " + what);
    }

    // after the lookups (answered on the next event-loop turn) have landed
    Timer { interval: 300; running: true; onTriggered: t.run() }
    Timer { interval: 15000; running: true; onTriggered: { console.error("lock-screen-test: FAIL timed out"); Qt.exit(3); } }

    function run() {
        var st = Lock.LockState, auth = t.authenticator;

        check("the view hands KDE's authenticator and user name to the shared state", st.auth === auth && st.userName === "Test User");
        check("settings are read without jq", st.use24h === false && st.mediaSlot === "bottom" && st.clockCfg.f === "serif");
        check("Wi-Fi 50% is two bars, Ethernet is seen", st.wifiLevel === 2 && st.ethernet === true);
        check("the wallpaper is the first candidate that exists", st.wallpaper === "/tmp/wall.png" && st.wallpaperVideo === "");

        var names = function (l) { return l.map(function (n) { return { name: n }; }); };
        check("the main display chosen in MacShell gets the full layout while it is connected",
              st.mainScreen === "DP-1" && st.primaryOf(names(["eDP-1", "DP-1"])) === "DP-1");
        check("without it the built-in panel does, and without that the first screen",
              st.primaryOf(names(["HDMI-A-1", "eDP-1"])) === "eDP-1" && st.primaryOf(names(["HDMI-A-1", "DP-2"])) === "HDMI-A-1" && st.primaryOf([]) === "");

        check("KDE's current player reaches the UI in seconds", ui.hasMedia && ui.player.trackTitle === "Song" && ui.player.length === 200 && !ui.player.isPlaying);

        // a password sent before PAM asks is held, not dropped
        st.poke();
        st.pass = "early"; st.submit();
        check("a password typed before the prompt waits for it", st.busy && auth.answers.length === 0 && auth.starts > 0);
        auth.promptForSecret = "Password: ";
        check("… and is sent once PAM asks", auth.answers.length === 1 && auth.answers[0] === "early");

        // wrong password
        auth.promptForSecret = "";
        auth.failed(0, null);
        check("a wrong password clears the field and says so", !st.busy && st.pass === "" && st.fails === 1 && st.message === "Incorrect password");
        var starts = auth.starts;
        st.message = "";
        auth.failed(1, null);
        check("a failed fingerprint read is not reported as a wrong password", st.message === "" && st.fails === 1 && auth.starts === starts);

        // no password set: PAM succeeds without asking, and nothing unlocks until the user confirms
        auth.succeeded();
        check("success without a prompt waits for Enter", st.open && !st.unlocking);
        st.open = false;

        // right password, after the prompt
        auth.promptForSecret = "Password: ";
        st.pass = "right"; st.submit();
        check("a password typed after the prompt is sent at once", auth.answers.length === 2 && auth.answers[1] === "right");
        auth.hadPrompt = true;
        auth.succeeded();
        check("success after a prompt starts the unlock", st.unlocking && !st.busy);

        if (bad > 0) { Qt.exit(1); return; }
        console.log("lock-screen-test: PASS (kde)");
        // … and LockState's unlock timer now calls Qt.quit(): exit code 0
    }
}
