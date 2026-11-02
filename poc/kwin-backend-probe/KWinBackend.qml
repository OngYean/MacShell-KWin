import QtQml
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string status: "connecting"
    property bool connected: false
    property int protocolVersion: 0
    property bool appMenuProtocolAvailable: false
    property var windows: []
    property string activeWindowId: ""
    property bool activeWindowMenuExported: false
    property var workspaces: ({ available: false })
    property var capabilities: ({})
    property string lastError: ""

    readonly property int windowCount: windows.length
    readonly property var activeWindow: {
        for (var i = 0; i < root.windows.length; i++) {
            if (root.windows[i].id === root.activeWindowId) return root.windows[i]
        }
        return null
    }

    function consumeSnapshot(line) {
        try {
            var snapshot = JSON.parse(line)
            root.status = snapshot.status || "invalid-response"
            root.connected = snapshot.status === "ok"
            root.protocolVersion = snapshot.protocolVersion || 0
            root.appMenuProtocolAvailable = Boolean(snapshot.appMenuProtocolAvailable)
            root.windows = snapshot.windows || []
            root.activeWindowId = snapshot.activeWindowId || ""
            root.activeWindowMenuExported = Boolean(snapshot.activeWindowMenuExported)
            root.workspaces = snapshot.workspaces || ({ available: false })
            root.capabilities = snapshot.capabilities || ({})
            if (snapshot.status === "unsupported") root.lastError = "KWin did not advertise Plasma Window Management"
            else root.lastError = ""
        } catch (error) {
            root.status = "invalid-response"
            root.connected = false
            root.lastError = String(error)
        }
    }

    Process {
        id: backendProcess
        command: ["macshell-kwin-backend-probe", "--watch"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.consumeSnapshot(data)
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.lastError = text.trim()
        }

        onExited: (exitCode, exitStatus) => {
            root.connected = false
            if (root.status !== "unsupported") root.status = "exited (" + exitCode + ")"
        }
    }
}
