// ~/.config/quickshell/CPMediaBtn.qml
import QtQuick

Rectangle {
    id: cpBtn
    property string btnText: ""
    property bool active: false
    signal activated()

    width: 32; height: 32
    radius: 8
    color: cpBtnMa.containsMouse ? Theme.surface3 : Theme.surface2

    scale: cpBtnMa.pressed ? 0.83 : (cpBtnMa.containsMouse ? 1.10 : 1.0)

    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on scale {
        NumberAnimation {
            duration: cpBtnMa.pressed ? 80 : 260
            easing.type: cpBtnMa.pressed ? Easing.InQuad : Easing.OutElastic
            easing.amplitude: 1.2
            easing.period: 0.38
        }
    }

    Text {
        anchors.centerIn: parent
        text: cpBtn.btnText
        font.pixelSize: 13
        color: cpBtn.active ? Theme.accent : Theme.subtext
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: cpBtnMa
        anchors.fill: parent
        hoverEnabled: true
        onClicked: cpBtn.activated()
    }
}
