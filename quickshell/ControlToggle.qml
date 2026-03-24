// ~/.config/quickshell/ControlToggle.qml
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property bool active: false
    signal clicked()

    height: 74
    radius: 14
    color: active ? Theme.accent : Theme.surface
    border.color: active ? Theme.accent2 : Theme.border
    border.width: 1

    Behavior on color { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }

    // Toggle spring bounce — plays on click
    SequentialAnimation {
        id: toggleAnim
        NumberAnimation {
            target: root; property: "scale"
            to: 0.91; duration: 90
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: root; property: "scale"
            to: 1.0; duration: 380
            easing.type: Easing.OutElastic
            easing.amplitude: 1.25
            easing.period: 0.40
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.icon
            color: root.active ? Theme.bg : Theme.subtext
            font.pixelSize: 20
            font.family: "JetBrainsMono Nerd Font"
            Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutQuad } }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.label
            color: root.active ? Theme.bg : Theme.text
            font.pixelSize: 12
            font.family: Theme.fontUI
            font.weight: 500
            Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutQuad } }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.active ? "Włączone" : "Wyłączone"
            color: root.active ? Qt.rgba(0, 0, 0, 0.45) : Theme.muted
            font.pixelSize: 9
            font.family: Theme.fontUI
            Behavior on color { ColorAnimation { duration: 220 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            toggleAnim.start()
            root.clicked()
        }
        onEntered: {
            if (!root.active) hoverAnim.start()
        }
        onExited: {
            if (!root.active) exitAnim.start()
        }
    }

    SequentialAnimation {
        id: hoverAnim
        NumberAnimation { target: root; property: "scale"; to: 1.04; duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.0 }
    }
    SequentialAnimation {
        id: exitAnim
        NumberAnimation { target: root; property: "scale"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
    }
}
