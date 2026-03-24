// ~/.config/quickshell/NotificationPopups.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    NotificationServer {
        id: server
        keepOnReload: true
        bodyMarkupSupported: false
    }

    property var notifList: []

    function rebuildList() {
        var arr = []
        var model = server.trackedNotifications
        for (var i = 0; i < model.count; i++) arr.push(model.get(i))
        notifList = arr
    }

    Connections {
        target: server.trackedNotifications
        function onCountChanged() { root.rebuildList() }
    }

    Component.onCompleted: root.rebuildList()

    Variants {
        model: root.notifList

        PanelWindow {
            id: win
            required property var modelData
            required property int index

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-notif"

            anchors.top: true
            anchors.right: true
            margins.top: 58 + index * 100
            margins.right: 12

            implicitWidth: 360
            implicitHeight: card.implicitHeight
            color: "transparent"

            // Slide in from right with spring + fade in
            NumberAnimation on margins.right {
                from: -380; to: 12
                duration: 420
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
                running: true
            }

            // Subtle drop-in from above
            NumberAnimation on margins.top {
                from: (58 + index * 100) - 14
                to:   58 + index * 100
                duration: 380
                easing.type: Easing.OutCubic
                running: true
            }

            Rectangle {
                id: card
                width: parent.width
                implicitHeight: col.implicitHeight + 24
                color: Theme.surface
                radius: Theme.radius
                border.color: urgencyBorderColor()
                border.width: 1

                // Fade in
                opacity: 0
                NumberAnimation on opacity {
                    from: 0; to: 1
                    duration: 300
                    easing.type: Easing.OutCubic
                    running: true
                }

                function urgencyBorderColor(): color {
                    var u = win.modelData.urgency
                    if (u === NotificationUrgency.Critical) return Theme.error
                    if (u === NotificationUrgency.Low)      return Theme.border
                    return Theme.accent
                }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                // Left urgency stripe
                Rectangle {
                    width: 3
                    anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                    anchors.topMargin: 8; anchors.bottomMargin: 8
                    color: card.urgencyBorderColor(); radius: 2
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // Timeout progress bar at bottom — gradient fill
                Item {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    anchors.leftMargin: 1; anchors.rightMargin: 1; anchors.bottomMargin: 1
                    height: 3

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.surface3
                        radius: 2
                    }

                    Rectangle {
                        id: progressBar
                        height: parent.height; radius: 2

                        property int timeout: win.modelData.expireTimeout > 0
                            ? win.modelData.expireTimeout : 5000

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Theme.accent2 }
                            GradientStop { position: 1.0; color: Theme.accent }
                        }

                        NumberAnimation on width {
                            from: card.width - 2; to: 0
                            duration: progressBar.timeout
                            running: true
                            easing.type: Easing.Linear
                            onFinished: win.modelData.expire()
                        }
                    }
                }

                ColumnLayout {
                    id: col
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    anchors.margins: 12; anchors.leftMargin: 18
                    spacing: 4

                    // App name row
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: win.modelData.appName || ""
                            color: Theme.muted; font.pixelSize: 10
                            font.family: Theme.fontUI; font.weight: Font.Medium
                            font.letterSpacing: 0.3
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 18; height: 18; radius: 4
                            color: dismissMa.containsMouse ? Theme.surface3 : "transparent"
                            scale: dismissMa.pressed ? 0.85 : (dismissMa.containsMouse ? 1.12 : 1.0)

                            Behavior on color { ColorAnimation { duration: 80 } }
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

                            Text { anchors.centerIn: parent; text: "✕"; color: Theme.muted; font.pixelSize: 9 }
                            MouseArea {
                                id: dismissMa; anchors.fill: parent; hoverEnabled: true
                                onClicked: win.modelData.dismiss()
                            }
                        }
                    }

                    // Summary
                    Text {
                        text: win.modelData.summary || ""
                        color: Theme.text; font.pixelSize: 13
                        font.family: Theme.fontUI; font.weight: Font.SemiBold
                        wrapMode: Text.WordWrap; Layout.fillWidth: true
                        visible: text !== ""; textFormat: Text.PlainText
                    }

                    // Body
                    Text {
                        text: win.modelData.body || ""
                        color: Theme.subtext; font.pixelSize: 11
                        font.family: Theme.fontUI; wrapMode: Text.WordWrap
                        Layout.fillWidth: true; maximumLineCount: 3
                        elide: Text.ElideRight; visible: text !== ""
                        textFormat: Text.PlainText
                    }

                    // Action buttons
                    RowLayout {
                        spacing: 6; visible: win.modelData.actions.length > 0
                        Layout.topMargin: 2

                        Repeater {
                            model: win.modelData.actions
                            delegate: Rectangle {
                                required property var modelData
                                height: 22; width: actionLabel.implicitWidth + 16
                                color: actionMa.containsMouse ? Theme.surface3 : Theme.surface2
                                radius: Theme.radiusSm; border.color: Theme.border; border.width: 1
                                scale: actionMa.pressed ? 0.92 : 1.0

                                Behavior on color { ColorAnimation { duration: 80 } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                                Text {
                                    id: actionLabel; anchors.centerIn: parent
                                    text: modelData.text || ""; color: Theme.text
                                    font.pixelSize: 10; font.family: Theme.fontUI
                                }
                                MouseArea {
                                    id: actionMa; anchors.fill: parent; hoverEnabled: true
                                    onClicked: { modelData.invoke(); win.modelData.dismiss() }
                                }
                            }
                        }
                    }
                }

                // Click anywhere to dismiss
                MouseArea {
                    anchors.fill: parent; z: -1
                    onClicked: win.modelData.dismiss()
                }
            }
        }
    }
}
