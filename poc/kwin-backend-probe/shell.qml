import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    function screenByName(outputName) {
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var candidate = Quickshell.screens[i]
            if (candidate.name === outputName) return candidate
        }
        return null
    }

    readonly property var testScreen: root.screenByName("eDP-1")

    KWinBackend {
        id: backend
    }

    PanelWindow {
        screen: root.testScreen
        visible: root.testScreen !== null
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 36
        color: "#20212a"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "macshell-kwin-backend-poc"

        Text {
            anchors.centerIn: parent
            color: "#f4f2f8"
            font.pixelSize: 14
            text: backend.connected
                ? "KWin backend · " + backend.windowCount + " windows · active "
                    + (backend.activeWindow ? "yes" : "no") + " · AppMenu protocol "
                    + (backend.appMenuProtocolAvailable ? "yes" : "no") + " · address "
                    + (backend.activeWindowMenuExported ? "yes" : "no") + " · workspace "
                    + (backend.workspaces.available
                        ? backend.workspaces.currentIndex + "/" + backend.workspaces.count
                        : "unavailable")
                : "KWin backend · " + backend.status
        }
    }
}
