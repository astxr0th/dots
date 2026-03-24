// ~/.config/quickshell/OSD.qml
// Dodaj do shell.qml: OSD {}
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    visible: osdItem.opacity > 0.001

    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 120

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.exclusiveZone: 0

    // ── Stan ───────────────────────────────────────────────────────
    property real   displayValue: 0
    property string displayIcon:  "󰕾"
    property string displayLabel: ""
    property bool   osdVisible:   false

    Timer {
        id: hideTimer
        interval: 1600
        repeat: false
        onTriggered: root.osdVisible = false
    }

    function showVolume(val) {
        var v = Math.round(val)
        var icon = v === 0 ? "󰖁" : v > 60 ? "󰕾" : v > 20 ? "󰖀" : "󰕿"
        root.displayIcon  = icon
        root.displayLabel = "Głośność"
        root.displayValue = v
        root.osdVisible   = true
        hideTimer.restart()
        // Synchronizuj GlobalState żeby reszta UI też wiedziała
        GlobalState.volume = v
    }

    function showBrightness(val) {
        var b = Math.round(val)
        var icon = b > 60 ? "󰃠" : b > 20 ? "󰃟" : "󰃞"
        root.displayIcon  = icon
        root.displayLabel = "Jasność"
        root.displayValue = b
        root.osdVisible   = true
        hideTimer.restart()
        GlobalState.brightness = b
    }

    // ── pactl subscribe — wykrywa zmiany głośności w czasie rzeczywistym ──
    // Nasłuchuje eventów "sink" i natychmiast odpytuje aktualną wartość
    Process {
        id: pactlSubscribe
        command: ["pactl", "subscribe"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                // Interesują nas tylko zdarzenia na sinkach (głośność)
                if (data.includes("'change' on sink")) {
                    volReader.running = false
                    volReader.running = true
                }
            }
        }

        // Restart jeśli padnie
        onRunningChanged: {
            if (!running) restartTimer.start()
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: pactlSubscribe.running = true
    }

    // Czyta aktualną głośność po zdarzeniu
    Process {
        id: volReader
        command: ["sh", "-c",
            "pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\\d+(?=%)' | head -1"
        ]
        running: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var v = parseInt(data.trim())
                if (!isNaN(v)) root.showVolume(v)
            }
        }
    }

    // ── Jasność — nasłuchuj GlobalState (brightnessctl nie ma subscribe) ──
    // SystemManager odpytuje co 2s, ale możemy też nasłuchiwać bezpośrednio
    property real _lastBri: -1

    Connections {
        target: GlobalState
        function onBrightnessChanged() {
            var b = GlobalState.brightness
            if (root._lastBri < 0) { root._lastBri = b; return }  // skip startup
            if (Math.abs(b - root._lastBri) < 1) return           // ignoruj mikro-dryf
            root._lastBri = b
            root.showBrightness(b)
        }
    }

    // ── Popup ──────────────────────────────────────────────────────
    Item {
        id: osdItem
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        width:  card.width
        height: card.height

        opacity: root.osdVisible ? 1.0 : 0.0
        scale:   root.osdVisible ? 1.0 : 0.88

        Behavior on opacity {
            NumberAnimation {
                duration: root.osdVisible ? 180 : 380
                easing.type: root.osdVisible ? Easing.OutCubic : Easing.InQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.osdVisible ? 260 : 380
                easing.type: root.osdVisible ? Easing.OutBack : Easing.InQuad
                easing.overshoot: 1.4
            }
        }

        Rectangle {
            id: card
            width: 220
            height: col.implicitHeight + 28
            radius: 16
            color: Theme.bg
            border.color: Theme.border
            border.width: 1

            // Górny shimmer
            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                anchors.topMargin: 1; anchors.leftMargin: 1; anchors.rightMargin: 1
                height: 1; radius: 16; color: "#ffffff"; opacity: 0.06
            }

            // Lewy pasek akcentowy
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top; anchors.bottom: parent.bottom
                anchors.topMargin: 14; anchors.bottomMargin: 14
                width: 2; radius: 2
                color: GlobalState.dynAccent; opacity: 0.7
                Behavior on color { ColorAnimation { duration: 600 } }
            }

            ColumnLayout {
                id: col
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 10

                // Ikona + label + wartość
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        id: iconTxt
                        text: root.displayIcon
                        font.pixelSize: 18
                        font.family: "JetBrainsMono Nerd Font"
                        color: GlobalState.dynAccent
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    Text {
                        text: root.displayLabel
                        color: Theme.subtext
                        font.pixelSize: 11; font.family: Theme.fontUI; font.weight: 500
                        Layout.fillWidth: true
                    }

                    Text {
                        text: Math.round(root.displayValue) + "%"
                        color: GlobalState.dynAccent
                        font.pixelSize: 13; font.family: Theme.fontUI; font.weight: 700
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }

                // Pasek postępu
                Item {
                    Layout.fillWidth: true
                    height: 6

                    Rectangle {
                        anchors.fill: parent; radius: 3; color: Theme.surface3
                    }

                    Rectangle {
                        id: fillBar
                        height: parent.height; radius: 3
                        width: Math.max(radius * 2,
                               parent.width * Math.min(1.0, root.displayValue / 100))
                        Behavior on width {
                            SmoothedAnimation { duration: 120; velocity: -1 }
                        }
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: GlobalState.dynAccent2 }
                            GradientStop { position: 1.0; color: GlobalState.dynAccent  }
                        }
                        // Połysk
                        Rectangle {
                            anchors.top: parent.top; anchors.left: parent.left
                            anchors.right: parent.right; anchors.topMargin: 1
                            anchors.leftMargin: 1; anchors.rightMargin: 1
                            height: 1; radius: 3; color: "#ffffff"; opacity: 0.25
                        }
                    }

                    // Kółko na końcu paska
                    Rectangle {
                        x: Math.max(0, fillBar.width - width / 2)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10; height: 10; radius: 5
                        color: Theme.bg
                        border.color: GlobalState.dynAccent; border.width: 2
                        Behavior on x { SmoothedAnimation { duration: 120; velocity: -1 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }
                }
            }
        }
    }
}
