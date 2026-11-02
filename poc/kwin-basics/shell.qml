import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    // Select by output name: Quickshell's screen list order differs from
    // kscreen-doctor's output order on the currently verified setup.
    function screenByName(outputName) {
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var candidate = Quickshell.screens[i]
            if (candidate.name === outputName) return candidate
        }
        return null
    }

    readonly property var testScreen: root.screenByName("eDP-1")

    Component.onCompleted: {
        if (root.testScreen) {
            console.log("[kwin-basics] target output:", root.testScreen.name,
                        root.testScreen.width + "x" + root.testScreen.height)
        } else {
            console.warn("[kwin-basics] second output is unavailable; no test surfaces will be shown")
        }
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
        WlrLayershell.namespace: "macshell-kwin-poc"

        Text {
            anchors.centerIn: parent
            text: "MacShell · KWin layer-shell POC"
            color: "#f4f2f8"
            font.pixelSize: 14
        }
    }

    PanelWindow {
        screen: root.testScreen
        visible: root.testScreen !== null
        anchors {
            bottom: true
            left: true
            right: true
        }
        implicitHeight: 76
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "macshell-kwin-poc"

        Rectangle {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 8
            }
            width: 250
            height: 56
            radius: 24
            color: "#d92d2f36"
            border.color: "#56ffffff"
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 14

                Repeater {
                    model: ["A", "B", "C"]

                    delegate: Rectangle {
                        required property string modelData
                        width: 38
                        height: 38
                        radius: 12
                        color: "#484a58"

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: "#f4f2f8"
                            font.pixelSize: 17
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}
