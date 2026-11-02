import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property var menuItems: []
    property string activeWindowId: ""
    property string activeAppId: ""
    property string status: "connecting"
    property var popupItem: null
    property var popupPath: []
    property real popupX: 0
    property real popupY: 36

    function appLabel() {
        if (root.activeAppId === "") return "No App"
        var parts = root.activeAppId.split(".")
        var label = parts[parts.length - 1]
        return label.length > 0 ? label.charAt(0).toUpperCase() + label.slice(1) : "App"
    }

    function consumeSnapshot(line) {
        try {
            var snapshot = JSON.parse(line)
            if (snapshot.status !== "ok") {
                root.status = snapshot.status || "invalid-response"
                root.menuItems = []
                root.activeAppId = ""
                root.activeWindowId = ""
                root.closeMenus(false)
                return
            }

            if (root.activeWindowId !== snapshot.activeWindowId) root.closeMenus(false)
            root.activeWindowId = snapshot.activeWindowId || ""
            root.activeAppId = snapshot.activeAppId || ""
            root.status = snapshot.menuStatus || "no-menu"
            root.menuItems = snapshot.menuStatus === "layout-retrieved" ? (snapshot.menuItems || []) : []
        } catch (error) {
            root.status = "invalid-response"
            root.menuItems = []
            root.closeMenus(false)
        }
    }

    function sendMenuEvent(action, item) {
        if (!item || item.id === undefined || item.id < 0) return
        menuProcess.write(JSON.stringify({ action: action, id: item.id }) + "\n")
    }

    function closeMenus(notify) {
        if (notify) {
            for (var i = root.popupPath.length - 1; i >= 0; i--) {
                root.sendMenuEvent("closed", root.popupPath[i])
            }
        }
        root.popupPath = []
        root.popupItem = null
    }

    function openMenu(item, x, y) {
        if (!item) return
        if (!item.children || item.children.length === 0) {
            root.sendMenuEvent("clicked", item)
            root.closeMenus(true)
            return
        }
        if (root.popupItem && root.popupItem.id === item.id && root.popupPath.length === 1) {
            root.closeMenus(true)
            return
        }
        root.closeMenus(true)
        root.popupPath = [item]
        root.popupItem = item
        root.popupX = x
        root.popupY = y
        root.sendMenuEvent("opened", item)
    }

    function openNestedMenu(item, rowY) {
        if (!item) return
        if (!item.children || item.children.length === 0) {
            root.sendMenuEvent("clicked", item)
            root.closeMenus(true)
            return
        }
        root.popupPath = root.popupPath.concat([item])
        root.popupItem = item
        root.popupX = root.popupX + menuPopup.implicitWidth - 4
        root.popupY = root.popupY + rowY
        root.sendMenuEvent("opened", item)
    }

    function screenByName(outputName) {
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var candidate = Quickshell.screens[i]
            if (candidate.name === outputName) return candidate
        }
        return null
    }

    readonly property var testScreen: root.screenByName("eDP-1")

    Process {
        id: menuProcess
        command: ["macshell-kwin-backend-probe", "--menu-watch"]
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.consumeSnapshot(data)
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.status = "helper-error"
        }

        onExited: (exitCode, exitStatus) => {
            root.status = "helper-exited-" + exitCode
            root.menuItems = []
            root.closeMenus(false)
        }
    }

    PanelWindow {
        id: panel
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
        WlrLayershell.namespace: "macshell-global-menu-poc"

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            Text {
                color: "#f4f2f8"
                font.pixelSize: 13
                font.bold: true
                text: root.appLabel()
            }

            Repeater {
                model: root.menuItems

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    visible: modelData.visible !== false
                    width: modelData.separator ? 1 : menuLabel.implicitWidth + 16
                    height: 28
                    radius: 5
                    color: menuMouse.containsMouse ? "#ffffff22" : "transparent"

                    Text {
                        id: menuLabel
                        anchors.centerIn: parent
                        visible: !modelData.separator
                        color: modelData.enabled === false ? "#888994" : "#f4f2f8"
                        font.pixelSize: 13
                        text: (modelData.checked ? "✓ " : "") + (modelData.label || "")
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 1
                        height: 18
                        visible: modelData.separator === true
                        color: "#777985"
                    }

                    MouseArea {
                        id: menuMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: modelData.enabled !== false && !modelData.separator
                        onClicked: root.openMenu(modelData, parent.x + parent.parent.x, panel.height)
                    }
                }
            }

            Text {
                visible: root.menuItems.length === 0
                color: "#a4a5b1"
                font.pixelSize: 12
                text: root.status === "layout-retrieved" ? "(empty menu)" : "(" + root.status + ")"
            }
        }
    }

    PopupWindow {
        id: menuPopup
        anchor.window: panel
        anchor.rect.x: root.popupX
        anchor.rect.y: root.popupY
        visible: root.popupItem !== null
        implicitWidth: 240
        implicitHeight: popupRows.implicitHeight + 8
        color: "#292a34"

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "#292a34"
            border.color: "#555662"

            Column {
                id: popupRows
                anchors.fill: parent
                anchors.margins: 4
                spacing: 1

                Repeater {
                    model: root.popupItem ? root.popupItem.children : []

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        visible: modelData.visible !== false
                        width: popupRows.width
                        height: modelData.separator ? 7 : 28
                        radius: 4
                        color: popupMouse.containsMouse ? "#ffffff22" : "transparent"

                        Text {
                            id: popupLabel
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !modelData.separator
                            color: modelData.enabled === false ? "#888994" : "#f4f2f8"
                            font.pixelSize: 13
                            text: (modelData.checked ? "✓ " : "") + (modelData.label || "")
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            height: 1
                            visible: modelData.separator === true
                            color: "#555662"
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.children && modelData.children.length > 0
                            color: "#a4a5b1"
                            font.pixelSize: 12
                            text: "›"
                        }

                        MouseArea {
                            id: popupMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: modelData.enabled !== false && !modelData.separator
                            onClicked: root.openNestedMenu(modelData, parent.y)
                        }
                    }
                }
            }
        }
    }
}
