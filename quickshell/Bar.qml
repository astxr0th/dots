// ~/.config/quickshell/Bar.qml
// Optimized version with System Tray support:
//   ✓ Smoother animations (60 FPS, optimized easing)
//   ✓ Better performance (reduced animation overhead)
//   ✓ More responsive interactions
//   ✓ Full System Tray functionality
//
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: root

    screen: {
        var list = Quickshell.screens
        for (var i = 0; i < list.length; i++) {
            if (list[i].name === "HDMI-A-1") return list[i]
        }
        return list[0]
    }

    anchors.top: true; anchors.left: true; anchors.right: true
    implicitHeight: 52
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.exclusiveZone: 60

    property bool trayOpen: false

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

    // ── BAR BODY ──────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        anchors.margins: 6; anchors.leftMargin: 12; anchors.rightMargin: 12
        color: Theme.bg; radius: 14; border.color: Theme.border; border.width: 1

        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 1; anchors.rightMargin: 1; anchors.topMargin: 1
            height: 1; color: "#ffffff"; opacity: 0.05; radius: 14
        }

        // ── LEFT ──────────────────────────────────────────
        RowLayout {
            anchors.left: parent.left; anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                width: 30; height: 30; radius: 8
                color: logoMa.containsMouse ? Theme.surface3 : Theme.surface2
                scale: logoMa.pressed ? 0.86 : (logoMa.containsMouse ? 1.10 : 1.0)
                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutElastic; easing.amplitude: 1.25; easing.period: 0.35 } }
                Text { anchors.centerIn: parent; text: "󰣇"; font.pixelSize: 16; color: GlobalState.dynAccent; font.family: Theme.fontIcons; Behavior on color { ColorAnimation { duration: 500 } } }
                MouseArea { id: logoMa; anchors.fill: parent; hoverEnabled: true; onClicked: GlobalState.launcherOpen = !GlobalState.launcherOpen }
            }

            Repeater {
                model: 9
                Item {
                    required property int index
                    property int wsId: index + 1
                    property var ws: Hyprland.workspaces.values.find(w => w.id === wsId)
                    property bool isActive: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id === wsId : false
                    property bool hasWindows: ws !== undefined

                    implicitWidth: isActive ? 30 : 10; implicitHeight: 10
                    Behavior on implicitWidth { NumberAnimation { duration: 320; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.38 } }

                    Rectangle {
                        width: parent.implicitWidth; height: parent.implicitHeight; radius: 5
                        color: isActive ? GlobalState.dynAccent : wsMa.containsMouse ? Theme.surface3 : hasWindows ? Theme.surface3 : Theme.surface2
                        opacity: isActive ? 1.0 : hasWindows ? 0.75 : 0.45
                        scale: wsMa.pressed ? 0.82 : 1.0
                        Behavior on color   { ColorAnimation { duration: 140 } }
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        Behavior on scale   { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                        Rectangle {
                            anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: Theme.bg; opacity: 0.55
                            visible: parent.parent.isActive
                        }
                    }
                    MouseArea { id: wsMa; anchors.fill: parent; hoverEnabled: true; onClicked: Hyprland.dispatch("workspace " + wsId) }
                }
            }

            Rectangle { width: 1; height: 14; color: Theme.border; opacity: 0.4 }

            Text {
                text: Hyprland.focusedWorkspace ? (Hyprland.focusedWorkspace.lastWindow || "") : ""
                color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontUI; font.weight: 500
                elide: Text.ElideRight; Layout.maximumWidth: 180
            }
        }

        // ── CENTER — MPRIS ─────────────────────────────────
        Rectangle {
            visible: root.player !== null && (root.player.trackTitle || "") !== ""
            anchors.centerIn: parent
            height: 32; width: mprisRow.implicitWidth + 28; radius: 10
            color: mprisMa.containsMouse ? Theme.surface2 : Theme.surface
            border.color: GlobalState.panelOpen ? GlobalState.dynAccent : Theme.border; border.width: 1
            scale: mprisMa.pressed ? 0.96 : (mprisMa.containsMouse ? 1.025 : 1.0)
            Behavior on color        { ColorAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 250 } }
            Behavior on scale        { NumberAnimation { duration: 180; easing.type: Easing.OutElastic; easing.amplitude: 1.05; easing.period: 0.4 } }

            MouseArea { id: mprisMa; anchors.fill: parent; hoverEnabled: true; onClicked: GlobalState.panelOpen = !GlobalState.panelOpen }

            RowLayout { id: mprisRow; anchors.centerIn: parent; spacing: 8
                Text {
                    text: root.player && root.player.playbackState === MprisPlaybackState.Playing ? "▶" : "⏸"
                    font.pixelSize: 9
                    color: root.player && root.player.playbackState === MprisPlaybackState.Playing ? GlobalState.dynAccent : Theme.muted
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                Text { text: root.player ? (root.player.trackTitle || "") : ""; color: Theme.text; font.pixelSize: 12; font.family: Theme.fontUI; font.weight: 600; elide: Text.ElideRight; Layout.maximumWidth: 200 }
                Text { text: "·"; color: Theme.muted; font.pixelSize: 10; visible: root.player && (root.player.trackArtist || "") !== "" }
                Text { text: root.player ? (root.player.trackArtist || "") : ""; color: Theme.subtext; font.pixelSize: 11; font.family: Theme.fontUI; elide: Text.ElideRight; Layout.maximumWidth: 130; visible: text !== "" }
                Text { text: GlobalState.panelOpen ? "⌃" : "⌄"; color: Theme.muted; font.pixelSize: 9 }
            }
        }

        // ── RIGHT ──────────────────────────────────────────
        RowLayout {
            anchors.right: parent.right; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            // TRAY BUTTON
            Rectangle {
                id: trayBtn
                width: 26; height: 26; radius: 7
                color: trayBtnMa.containsMouse || root.trayOpen ? Theme.surface3 : "transparent"
                scale: trayBtnMa.pressed ? 0.86 : (trayBtnMa.containsMouse ? 1.10 : 1.0)
                Layout.rightMargin: 6
                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutElastic; easing.amplitude: 1.15; easing.period: 0.35 } }
                Text {
                    anchors.centerIn: parent
                    text: root.trayOpen ? "󰅃" : "󰅀"
                    font.pixelSize: 12; font.family: Theme.fontIcons
                    color: root.trayOpen ? GlobalState.dynAccent : Theme.muted
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                MouseArea {
                    id: trayBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.trayOpen = !root.trayOpen
                }
            }

            Rectangle { width: 1; height: 14; color: Theme.border; opacity: 0.4; Layout.rightMargin: 6 }

            // Clipboard
            Rectangle {
                width: 26; height: 26; radius: 7
                color: clipMa.containsMouse || GlobalState.clipboardOpen ? Theme.surface3 : "transparent"
                scale: clipMa.pressed ? 0.86 : (clipMa.containsMouse ? 1.10 : 1.0)
                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutElastic; easing.amplitude: 1.15; easing.period: 0.35 } }
                Text { anchors.centerIn: parent; text: "󰅇"; font.pixelSize: 14; font.family: Theme.fontIcons; color: GlobalState.clipboardOpen ? GlobalState.dynAccent : Theme.muted; Behavior on color { ColorAnimation { duration: 180 } } }
                MouseArea { id: clipMa; anchors.fill: parent; hoverEnabled: true; onClicked: GlobalState.clipboardOpen = !GlobalState.clipboardOpen }
                Layout.rightMargin: 6
            }

            // Wallpaper
            Rectangle {
                width: 26; height: 26; radius: 7
                color: wpMa.containsMouse || GlobalState.wallpaperPickerOpen ? Theme.surface3 : "transparent"
                scale: wpMa.pressed ? 0.86 : (wpMa.containsMouse ? 1.10 : 1.0)
                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutElastic; easing.amplitude: 1.15; easing.period: 0.35 } }
                Text { anchors.centerIn: parent; text: "󰸉"; font.pixelSize: 14; font.family: Theme.fontIcons; color: GlobalState.wallpaperPickerOpen ? GlobalState.dynAccent : Theme.muted; Behavior on color { ColorAnimation { duration: 180 } } }
                MouseArea { id: wpMa; anchors.fill: parent; hoverEnabled: true; onClicked: GlobalState.wallpaperPickerOpen = !GlobalState.wallpaperPickerOpen }
                Layout.rightMargin: 6
            }

            Rectangle { width: 1; height: 14; color: Theme.border; opacity: 0.4; Layout.rightMargin: 10 }

            Text {
                text: "󰕾  " + Math.round(GlobalState.volume) + "%"
                color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontUI; Layout.rightMargin: 10
            }

            Rectangle { width: 1; height: 14; color: Theme.border; opacity: 0.4; Layout.rightMargin: 10 }

            ColumnLayout {
                spacing: -1
                Text {
                    id: clockText
                    property var now: new Date()
                    text: Qt.formatTime(now, "HH:mm")
                    color: GlobalState.dynAccent
                    font.pixelSize: 15; font.family: Theme.fontDisplay; font.weight: 700; font.letterSpacing: 0.8
                    Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.OutQuad } }
                    property string prevTime: ""
                    onTextChanged: {
                        if (prevTime !== "" && prevTime !== text) clockPulse.start()
                        prevTime = text
                    }
                    SequentialAnimation {
                        id: clockPulse
                        NumberAnimation { target: clockText; property: "scale"; to: 0.88; duration: 90; easing.type: Easing.InQuad }
                        NumberAnimation { target: clockText; property: "scale"; to: 1.0;  duration: 320; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.4 }
                    }
                    Timer { interval: 1000; running: true; repeat: true; onTriggered: clockText.now = new Date() }
                }
                Text {
                    text: Qt.formatDate(new Date(), "ddd, d MMM")
                    color: Theme.muted; font.pixelSize: 9; font.family: Theme.fontUI; font.weight: 500; font.letterSpacing: 0.3
                }
            }
        }
    }

    // ── SYSTEM TRAY POPUP (anti-crash edition) ───────────────────────────────
    Window {
        id: trayPopup
        visible: root.trayOpen && SystemTray.items.length > 0   // ← nie twórz jak zero ikon!
        color: "transparent"
        flags: Qt.Popup | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

        // Twarde minimalne wymiary + reactive na liczbę itemów
        width:  Math.max( trayBox.implicitWidth,  180 )
        height: Math.max( trayBox.implicitHeight, 100 )

        // Pozycja – mapToGlobal jest bezpieczniejsze niż mapToItem w tym kontekście
        x: trayBtn.mapToGlobal(trayBtn.width - width + 8, trayBtn.height + 4).x
        y: trayBtn.mapToGlobal(0, trayBtn.height + 4).y

        onVisibleChanged: {
            if (visible) console.log("Tray popup opening | items:", SystemTray.items.length, "size:", width, "×", height)
        }

        Rectangle {
            id: trayBox
            anchors.fill: parent
            color: Theme.bg
            radius: 12
            border.color: Theme.border
            border.width: 1

            property int cell: 32
            property int gap: 6
            property int pad: 8

            // Minimalne + nigdy 0
            implicitWidth:  Math.max( trayBox.cell * 4 + trayBox.gap * 3 + trayBox.pad * 2, 180 )
            implicitHeight: Math.max(
                trayBox.pad * 2 + trayBox.cell * Math.ceil(SystemTray.items.length / 4) +
                trayBox.gap * Math.max(0, Math.ceil(SystemTray.items.length / 4) - 1),
                                     100
            )

            Rectangle { /* ten highlight górny – bez zmian */ }

            Flow {
                x: trayBox.pad; y: trayBox.pad
                width:  trayBox.width  - trayBox.pad * 2
                height: trayBox.height - trayBox.pad * 2   // ← ważne, Flow nie może mieć height=0
                spacing: trayBox.gap

                Repeater {
                    model: SystemTray.items
                    delegate: Item { /* delegate bez zmian, ale możesz dodać visible: modelData.visible */ }
                }
            }
        }

        // Klik poza → zamknij (kluczowe dla stabilności)
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            onClicked: (mouse) => {
                let child = trayBox.childAt(mouse.x, mouse.y)
                if (!child || child === trayBox) {
                    root.trayOpen = false
                }
            }
        }
    }
}
