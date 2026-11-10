// ScreenCorners — rounds each screen's corners like a MacBook's display (Settings → Appearance → "Screen corner radius").
//
// Four small surfaces per screen, one in each corner on the Overlay layer, each painting the black outside of a quarter
// circle. They never take the pointer (empty input mask) and reserve no space. Four corner-sized surfaces rather than one
// transparent surface over the whole screen: the compositor has next to nothing to blend.
// Nothing exists while the radius is 0 (the default).
// Known limits: the corners are part of the picture, so screenshots and screen recordings show them, and a fullscreen
// window under them can't be scanned out directly.
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    property var hub: null
    readonly property int radius: (hub && hub.dock) ? Math.max(0, Math.round(hub.dock.screenCornerRadius)) : 0

    Variants {
        model: root.radius > 0 ? Quickshell.screens : []
        Scope {
            id: perScreen
            required property var modelData
            Variants {
                model: [0, 1, 2, 3]          // top-left, top-right, bottom-left, bottom-right
                PanelWindow {
                    id: win
                    required property var modelData       // the corner's number
                    readonly property bool atRight: modelData % 2 === 1
                    readonly property bool atBottom: modelData >= 2
                    screen: perScreen.modelData
                    anchors { top: !win.atBottom; bottom: win.atBottom; left: !win.atRight; right: win.atRight }
                    implicitWidth: root.radius
                    implicitHeight: root.radius
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    WlrLayershell.namespace: root.hub.compositor.layerNamespace("macshell-corners")
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                    mask: Region {}

                    // A square frame four radii wide with a border one radius thick: its hole is a rounded rectangle whose
                    // corner has exactly this radius. The hole's corner sits on the screen's corner; the clip keeps the one
                    // radius-sized piece of the frame around it. (A Rectangle, not a Canvas: sharp at any display scale.)
                    Item {
                        anchors.fill: parent
                        clip: true
                        Rectangle {
                            x: win.atRight ? -2 * root.radius : -root.radius
                            y: win.atBottom ? -2 * root.radius : -root.radius
                            width: 4 * root.radius
                            height: 4 * root.radius
                            radius: 2 * root.radius
                            color: "transparent"
                            border.width: root.radius
                            border.color: "black"
                        }
                    }
                }
            }
        }
    }
}
