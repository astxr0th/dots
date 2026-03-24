// ~/.config/quickshell/MediaBtn.qml
import Quickshell.Wayland
import QtQuick

Rectangle {
    id: btn
    property string btnText: ""
    property int fontSize: 13
    property bool active: false
    signal activated()

    width: 28; height: 28
    radius: 6
    color: area.containsMouse ? "#352d55" : "transparent"

    // Press scale spring — very tactile
    scale: area.pressed ? 0.82 : (area.containsMouse ? 1.10 : 1.0)

    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on scale {
        NumberAnimation {
            duration: area.pressed ? 80 : 280
            easing.type: area.pressed ? Easing.InQuad : Easing.OutElastic
            easing.amplitude: 1.3
            easing.period: 0.35
        }
    }

    Text {
        anchors.centerIn: parent
        text: btn.btnText
        font.pixelSize: btn.fontSize
        color: btn.active ? "#c084fc" : "#9d8ec4"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: btn.activated()
    }
}
