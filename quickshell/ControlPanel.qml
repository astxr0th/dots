// ~/.config/quickshell/ControlPanel.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    // Keep window alive during close animation
    visible: GlobalState.panelOpen || panel.opacity > 0.005

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 9999
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-controlpanel"
    WlrLayershell.keyboardFocus: GlobalState.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: 0

    property MprisPlayer player: {
        var pl = Mpris.players.values
        if (!pl || pl.length === 0) return null
        for (var i = 0; i < pl.length; i++) {
            if (pl[i]?.identity?.toLowerCase().includes("spotify")) return pl[i]
        }
        for (var i = 0; i < pl.length; i++) {
            var id = (pl[i]?.identity || "").toLowerCase()
            if (id.includes("chrom") || id.includes("firefox") || id.includes("zen") || id.includes("brave"))
                return pl[i]
        }
        return pl[0] || null
    }

    property bool isPlaying: player !== null && player.playbackState === MprisPlaybackState.Playing

    // Backdrop — fades in/out with panel
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: GlobalState.panelOpen ? 0.28 : 0.0
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutQuad } }
        z: 0
        MouseArea {
            anchors.fill: parent
            onClicked: GlobalState.panelOpen = false
        }
    }

    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 58
        width: 360
        implicitHeight: mainCol.implicitHeight + 28
        z: 1
        color: Theme.bg
        radius: 16
        border.color: Theme.border
        border.width: 1

        // ── Open / close animation ─────────────────────
        property real slideOffset: GlobalState.panelOpen ? 0 : -22
        opacity: GlobalState.panelOpen ? 1.0 : 0.0
        scale: GlobalState.panelOpen ? 1.0 : 0.95

        Behavior on slideOffset {
            NumberAnimation {
                duration: GlobalState.panelOpen ? 380 : 240
                easing.type: GlobalState.panelOpen ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.4
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: GlobalState.panelOpen ? 300 : 220
                easing.type: GlobalState.panelOpen ? Easing.OutCubic : Easing.InQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: GlobalState.panelOpen ? 400 : 220
                easing.type: GlobalState.panelOpen ? Easing.OutElastic : Easing.InQuad
                easing.amplitude: 1.1
                easing.period: 0.45
            }
        }

        transform: Translate { y: panel.slideOffset }

        layer.enabled: true
        layer.effect: null

        // Top shimmer line
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1; anchors.leftMargin: 1; anchors.rightMargin: 1
            height: 1; color: "#ffffff"; opacity: 0.06; radius: 16
        }

        // Left accent bar
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 18; anchors.bottomMargin: 18
            width: 2; radius: 2
            color: Theme.accent; opacity: 0.5

            Behavior on color { ColorAnimation { duration: 600 } }
        }

        ColumnLayout {
            id: mainCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            spacing: 10

            // ── Header ────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4

                Text {
                    text: "Control Center"
                    color: Theme.text
                    font.pixelSize: 13
                    font.family: Theme.fontUI
                    font.weight: 700
                    font.letterSpacing: 0.4
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 22; height: 22; radius: 6
                    color: closeMa.containsMouse ? Theme.surface3 : Theme.surface2
                    scale: closeMa.pressed ? 0.85 : (closeMa.containsMouse ? 1.10 : 1.0)

                    Behavior on color { ColorAnimation { duration: 80 } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

                    Text {
                        anchors.centerIn: parent; text: "✕"
                        color: Theme.muted; font.pixelSize: 10
                    }
                    MouseArea {
                        id: closeMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: GlobalState.panelOpen = false
                    }
                }
            }

            // ── Music Card ────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: musicCol.implicitHeight + 28
                color: Theme.surface
                radius: 12
                border.color: Theme.border
                border.width: 1
                clip: false

                Image {
                    anchors.fill: parent
                    source: root.player ? (root.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.07
                    visible: status === Image.Ready
                }

                ColumnLayout {
                    id: musicCol
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors.topMargin: 14; anchors.leftMargin: 14; anchors.rightMargin: 14
                    spacing: 10

                    // No player fallback
                    RowLayout {
                        visible: root.player === null
                        spacing: 8
                        Text { text: "󰝚"; color: Theme.muted; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
                        Text { text: "Brak odtwarzacza"; color: Theme.muted; font.pixelSize: 12; font.family: Theme.fontUI }
                    }

                    // Track info
                    RowLayout {
                        visible: root.player !== null
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            width: 48; height: 48; radius: 10
                            color: Theme.surface2; clip: true
                            // Spin on track change
                            property string currentSrc: root.player ? (root.player.trackArtUrl || "") : ""
                            onCurrentSrcChanged: artSpinAnim.start()
                            SequentialAnimation {
                                id: artSpinAnim
                                NumberAnimation { target: artContainer; property: "scale"; to: 0.8; duration: 120; easing.type: Easing.InQuad }
                                NumberAnimation { target: artContainer; property: "scale"; to: 1.0; duration: 300; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.4 }
                            }

                            Item {
                                id: artContainer
                                anchors.fill: parent

                                Image {
                                    id: artImg
                                    anchors.fill: parent
                                    source: root.player ? (root.player.trackArtUrl || "") : ""
                                    fillMode: Image.PreserveAspectCrop
                                }
                                Text {
                                    anchors.centerIn: parent; text: "󰝚"
                                    color: Theme.muted; font.pixelSize: 18
                                    font.family: "JetBrainsMono Nerd Font"
                                    visible: artImg.status !== Image.Ready
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                Layout.fillWidth: true
                                text: root.player ? (root.player.trackTitle || "—") : "—"
                                color: Theme.text; font.pixelSize: 13
                                font.family: Theme.fontUI; font.weight: 600
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.player ? (root.player.trackArtist || "") : ""
                                color: Theme.subtext; font.pixelSize: 11
                                font.family: Theme.fontUI; elide: Text.ElideRight
                            }
                        }
                    }

                    // Progress bar — spring physics
                    Item {
                        visible: root.player !== null
                        Layout.fillWidth: true
                        implicitHeight: 6; height: 6

                        Rectangle { anchors.fill: parent; color: Theme.surface3; radius: 3 }

                        Rectangle {
                            property real prog: {
                                if (!root.player) return 0
                                var len = root.player.length
                                return (len > 0) ? Math.min(1, root.player.position / len) : 0
                            }
                            width: Math.max(6, parent.width * prog)
                            height: parent.height
                            radius: 3

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Theme.accent }
                                GradientStop { position: 1.0; color: Theme.accent2 }
                            }

                            Behavior on width { SmoothedAnimation { duration: 400; velocity: -1; easing.type: Easing.OutCubic } }

                            // Thumb dot
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: -4
                                width: 8; height: 8; radius: 4
                                color: Theme.accent2
                                border.color: Theme.bg; border.width: 1.5
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.player && root.player.length > 0)
                                    root.player.position = (mouseX / width) * root.player.length
                            }
                        }
                    }

                    // Playback controls
                    RowLayout {
                        visible: root.player !== null
                        Layout.fillWidth: true
                        Layout.bottomMargin: 2
                        spacing: 0

                        CPMediaBtn {
                            btnText: "⇄"
                            active: root.player ? root.player.shuffle : false
                            onActivated: { if (root.player) root.player.shuffle = !root.player.shuffle }
                        }
                        Item { Layout.fillWidth: true }
                        CPMediaBtn { btnText: "⏮"; onActivated: { if (root.player) root.player.previous() } }

                        // Play/Pause — elastic press + glow pulse when playing
                        Rectangle {
                            id: playBtn
                            width: 36; height: 36; radius: 18
                            color: playMa.containsMouse ? Theme.accent2 : Theme.accent
                            Layout.leftMargin: 8; Layout.rightMargin: 8

                            scale: playMa.pressed ? 0.88 : 1.0

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 280
                                    easing.type: Easing.OutElastic
                                    easing.amplitude: 1.3
                                    easing.period: 0.35
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.isPlaying ? "⏸" : "▶"
                                font.pixelSize: 13; color: Theme.bg

                                Behavior on text {
                                    SequentialAnimation {
                                        NumberAnimation { target: parent; property: "opacity"; to: 0; duration: 80 }
                                        NumberAnimation { target: parent; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutQuad }
                                    }
                                }
                            }

                            MouseArea {
                                id: playMa; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    if (root.player) root.player.togglePlaying()
                                }
                            }
                        }

                        CPMediaBtn { btnText: "⏭"; onActivated: { if (root.player) root.player.next() } }
                        Item { Layout.fillWidth: true }
                        CPMediaBtn {
                            btnText: "↻"
                            active: root.player && root.player.loopStatus !== MprisLoopState.None
                            onActivated: {
                                if (!root.player) return
                                root.player.loopStatus = root.player.loopStatus === MprisLoopState.None
                                    ? MprisLoopState.Playlist : MprisLoopState.None
                            }
                        }
                    }
                }
            }

            // ── Volume Slider ─────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 60
                color: Theme.surface
                radius: 12
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 8

                    RowLayout {
                        Text {
                            text: GlobalState.volume > 60 ? "󰕾" : GlobalState.volume > 20 ? "󰖀" : "󰕿"
                            color: Theme.accent; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        Text {
                            text: "Volume"; color: Theme.subtext; font.pixelSize: 11
                            font.family: Theme.fontUI; Layout.leftMargin: 4
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Math.round(GlobalState.volume) + "%"
                            color: Theme.accent; font.pixelSize: 11
                            font.family: Theme.fontUI; font.weight: 700
                        }
                    }

                    Item {
                        Layout.fillWidth: true; height: 16

                        // Track
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 4; radius: 2
                            color: Theme.surface3

                            Rectangle {
                                width: parent.width * (GlobalState.volume / 100)
                                height: parent.height; radius: 2

                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: Theme.accent }
                                    GradientStop { position: 1.0; color: Theme.accent2 }
                                }

                                Behavior on width { SmoothedAnimation { duration: 80; velocity: -1 } }
                            }
                        }

                        // Thumb
                        Rectangle {
                            id: volThumb
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - 14, (GlobalState.volume / 100) * parent.width - 7))
                            width: 14; height: 14; radius: 7
                            color: Theme.bg
                            border.color: Theme.accent; border.width: 2

                            scale: volArea.pressed ? 1.25 : (volArea.containsMouse ? 1.12 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                        }

                        MouseArea {
                            id: volArea
                            anchors.fill: parent; hoverEnabled: true
                            onPressed: {
                                var v = Math.max(0, Math.min(100, mouseX / width * 100))
                                GlobalState.volume = v
                                SystemManager.setVolume(Math.round(v))
                            }
                            onPositionChanged: {
                                if (pressed) GlobalState.volume = Math.max(0, Math.min(100, mouseX / width * 100))
                            }
                            onReleased: SystemManager.setVolume(Math.round(GlobalState.volume))
                        }
                    }
                }
            }

            // ── Toggles ───────────────────────────────────
            RowLayout {
                Layout.fillWidth: true; spacing: 8

                ControlToggle {
                    Layout.fillWidth: true
                    icon: "󱡂"; label: "Cava"
                    active: GlobalState.cavaEnabled
                    onClicked: GlobalState.cavaEnabled = !GlobalState.cavaEnabled
                }
                ControlToggle {
                    Layout.fillWidth: true
                    icon: "󰖔"; label: "Night Light"
                    active: GlobalState.nightLight
                    onClicked: {
                        GlobalState.nightLight = !GlobalState.nightLight
                        SystemManager.toggleNightLight(GlobalState.nightLight)
                    }
                }
                ControlToggle {
                    Layout.fillWidth: true
                    icon: "󱥌"; label: "Shadery"
                    active: GlobalState.shadersEnabled
                    onClicked: GlobalState.shadersEnabled = !GlobalState.shadersEnabled
                }
            }

            // ── Power Buttons ─────────────────────────────
            RowLayout {
                Layout.fillWidth: true; spacing: 6; Layout.bottomMargin: 4

                // Sleep
                Rectangle {
                    id: sleepRect
                    Layout.fillWidth: true; height: 44; radius: 10
                    color: sleepMa.containsMouse ? Theme.surface3 : Theme.surface
                    border.color: sleepMa.containsMouse ? Theme.muted : Theme.border
                    border.width: 1
                    scale: sleepMa.pressed ? 0.93 : 1.0

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                    ColumnLayout { anchors.centerIn: parent; spacing: 1
                        Text { Layout.alignment: Qt.AlignHCenter; text: "󰤄"; color: Theme.muted; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "Sleep"; color: Theme.muted; font.pixelSize: 9; font.family: Theme.fontUI }
                    }
                    MouseArea { id: sleepMa; anchors.fill: parent; hoverEnabled: true; onClicked: SystemManager.suspend() }
                }

                // Reboot
                Rectangle {
                    Layout.fillWidth: true; height: 44; radius: 10
                    color: rebootMa.containsMouse ? Theme.surface3 : Theme.surface
                    border.color: rebootMa.containsMouse ? Theme.warning : Theme.border
                    border.width: 1
                    scale: rebootMa.pressed ? 0.93 : 1.0

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                    ColumnLayout { anchors.centerIn: parent; spacing: 1
                        Text { Layout.alignment: Qt.AlignHCenter; text: "󰜉"; color: Theme.warning; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "Reboot"; color: Theme.muted; font.pixelSize: 9; font.family: Theme.fontUI }
                    }
                    MouseArea { id: rebootMa; anchors.fill: parent; hoverEnabled: true; onClicked: SystemManager.reboot() }
                }

                // Power off
                Rectangle {
                    Layout.fillWidth: true; height: 44; radius: 10
                    color: powerMa.containsMouse ? Theme.surface3 : Theme.surface
                    border.color: powerMa.containsMouse ? Theme.error : Theme.border
                    border.width: 1
                    scale: powerMa.pressed ? 0.93 : 1.0

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                    ColumnLayout { anchors.centerIn: parent; spacing: 1
                        Text { Layout.alignment: Qt.AlignHCenter; text: "󰐥"; color: Theme.error; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "Power off"; color: Theme.muted; font.pixelSize: 9; font.family: Theme.fontUI }
                    }
                    MouseArea { id: powerMa; anchors.fill: parent; hoverEnabled: true; onClicked: SystemManager.poweroff() }
                }
            }
        }
    }
}
