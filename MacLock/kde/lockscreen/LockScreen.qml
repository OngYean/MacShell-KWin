// MacLock as KDE's lock screen. KDE's locker (kscreenlocker) loads this file from the Plasma/Shell package
// com.macshell.lock, once per screen, and keeps doing the locking itself: PAM, the idle and sleep triggers, the
// restart after a crash. If this file fails to load, KDE shows its built-in fallback screen instead.
// Try it in a window, without locking:  kscreenlocker_greet --testing --shell <path to the package>
import QtQuick
import QtQuick.Window
import "ui" as Ui

Item {
    id: root
    // set by kscreenlocker once the first frame is on screen
    property bool viewVisible: false
    implicitWidth: 800
    implicitHeight: 600

    // the UI font ("Open Runde") ships with MacLock
    FontLoader { source: Qt.resolvedUrl("ui/fonts/OpenRunde-Regular.otf") }
    FontLoader { source: Qt.resolvedUrl("ui/fonts/OpenRunde-Semibold.otf") }

    Ui.LockScreen {
        anchors.fill: parent
        st: LockState
        // the full layout goes on KDE's primary screen (the first one Qt lists); the others show wallpaper and clock
        isPrimary: !Screen.name || Application.screens.length === 0 || Screen.name === Application.screens[0].name
    }

    // authenticator, kscreenlocker_userName and kscreenlocker_userImage are provided by kscreenlocker
    Component.onCompleted: LockState.attach(authenticator, kscreenlocker_userName, kscreenlocker_userImage)
}
