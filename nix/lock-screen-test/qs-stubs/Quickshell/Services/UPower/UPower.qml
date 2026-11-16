pragma Singleton
import QtQuick

QtObject {
    property QtObject displayDevice: QtObject {
        property bool isPresent: true
        property real percentage: 0.42
        property int state: 1
    }
}
