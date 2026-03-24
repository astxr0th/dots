// ~/.config/quickshell/WallpaperPicker.qml
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: root

    // Stay alive during close animation
    visible: GlobalState.wallpaperPickerOpen || pickerContainer.containerOpacity > 0.005

    anchors.top: true; anchors.bottom: true
    anchors.left: true; anchors.right: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-wallpaper"
    WlrLayershell.keyboardFocus: GlobalState.wallpaperPickerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string walCacheDir:  Quickshell.env("HOME") + "/.cache/wal"

    property var    wallpapers:       []
    property string currentWallpaper: ""
    property bool   loading:          false
    property int    previewIndex:     0
    property string previewPath:      wallpapers.length > 0 ? wallpapers[previewIndex] : ""
    property string previewName:      previewPath !== ""
    ? previewPath.split("/").pop().replace(/\.[^.]+$/, "") : ""

    Connections {
        target: GlobalState
        function onWallpaperPickerOpenChanged() {
            if (GlobalState.wallpaperPickerOpen) {
                root.scanWallpapers()
                root.loadCurrentWallpaper()
            }
        }
    }

    // ── Scan ──────────────────────────────────────────
    Process {
        id: scanProcess
        command: ["bash", "-c",
        "find " + root.wallpaperDir +
        " -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png'" +
        " -o -iname '*.webp' -o -iname '*.gif' \\) 2>/dev/null | sort"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { var t=data.trim(); if(t!=="") root.wallpapers=root.wallpapers.concat([t]) }
        }
        onRunningChanged: {
            if (!running) {
                root.loading = false
                var idx = root.wallpapers.indexOf(root.currentWallpaper)
                if (idx >= 0) { root.previewIndex = idx; strip.positionViewAtIndex(idx, ListView.Center) }
            }
        }
    }

    Process {
        id: currentWpProcess
        command: ["bash", "-c", "swww query 2>/dev/null | grep -oP 'image: \\K.*' | head -1 | tr -d '\\n'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { var t=data.trim(); if(t!=="") root.currentWallpaper=t }
        }
    }

    Process {
        id: setWpProcess
        property string wpPath: ""
        command: ["swww", "img", wpPath, "--transition-type", "fade", "--transition-duration", "1"]
        running: false
        onRunningChanged: {
            if (!running) {
                root.currentWallpaper = wpPath
                walProcess.wpPath = wpPath
                walProcess.running = false
                walProcess.running = true
            }
        }
    }

    Process {
        id: walProcess
        property string wpPath: ""
        command: ["wal", "-i", wpPath, "-n", "-q", "--saturate", "0.8"]
        running: false
        onRunningChanged: {
            if (!running) {
                readColorsProcess.buf = ""
                readColorsProcess.running = false
                readColorsProcess.running = true
            }
        }
    }

    Process {
        id: readColorsProcess
        command: ["cat", root.walCacheDir + "/colors.json"]
        running: false
        property string buf: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { readColorsProcess.buf += data + "\n" }
        }
        onRunningChanged: {
            if (!running && buf !== "") {
                GlobalState.applyWalColors(buf)
                buf = ""
            }
        }
    }

    Component.onCompleted: {
        readColorsProcess.running = false
        readColorsProcess.running = true
    }

    function scanWallpapers() { root.wallpapers = []; root.loading = true; scanProcess.running = false; scanProcess.running = true }
    function loadCurrentWallpaper() { currentWpProcess.running = false; currentWpProcess.running = true }
    function applyWallpaper(path) { setWpProcess.wpPath = path; setWpProcess.running = false; setWpProcess.running = true }
    function close() { GlobalState.wallpaperPickerOpen = false }

    onPreviewIndexChanged: {
        if (root.wallpapers.length === 0) return
            var p = root.wallpapers[root.previewIndex]
            previewCard.crossfadeTo("file://" + p)
            bgBlur.opacity = 0
            bgBlur.source = "file://" + p
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { GlobalState.wallpaperPickerOpen = !GlobalState.wallpaperPickerOpen }
        function show(): void   { GlobalState.wallpaperPickerOpen = true }
        function hide(): void   { root.close() }
    }

    // ── Animated container ────────────────────────────
    Item {
        id: pickerContainer
        anchors.fill: parent

        property real containerOpacity: GlobalState.wallpaperPickerOpen ? 1.0 : 0.0
        opacity: containerOpacity

        Behavior on containerOpacity {
            NumberAnimation {
                duration: GlobalState.wallpaperPickerOpen ? 340 : 260
                easing.type: GlobalState.wallpaperPickerOpen ? Easing.OutCubic : Easing.InQuad
            }
        }

        // Blurred bg preview
        Image {
            id: bgBlur
            anchors.fill: parent
            source: root.previewPath !== "" ? "file://" + root.previewPath : ""
            fillMode: Image.PreserveAspectCrop
            smooth: true; asynchronous: true; cache: true
            opacity: 0

            layer.enabled: true
            layer.effect: GaussianBlur {
                radius: 100
                samples: 24
            }

            onStatusChanged: { if (status === Image.Ready) bgFadeIn.start() }
            NumberAnimation { id: bgFadeIn; target: bgBlur; property: "opacity"; from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }
        }

        Rectangle { anchors.fill: parent; color: "#000"; opacity: 0.68 }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#aa000000" }
                GradientStop { position: 0.28; color: "transparent" }
                GradientStop { position: 0.72; color: "transparent" }
                GradientStop { position: 1.0;  color: "#dd000000" }
            }
        }

        MouseArea { anchors.fill: parent; z: 0; onClicked: root.close() }

        // ── Top bar ───────────────────────────────────────
        Item {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 60; z: 10
            Rectangle { anchors.fill: parent; color: "#000"; opacity: 0.3 }
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#22ffffff" }

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 24; anchors.rightMargin: 24; spacing: 12

                Rectangle {
                    width: 32; height: 32; radius: 9
                    color: closeMa.containsMouse ? "#33ffffff" : "#18ffffff"
                    border.color: "#22ffffff"; border.width: 1
                    scale: closeMa.pressed ? 0.88 : (closeMa.containsMouse ? 1.08 : 1.0)

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.4 } }

                    Text { anchors.centerIn: parent; text: "✕"; color: "#fff"; font.pixelSize: 11 }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.close() }
                }

                Rectangle { width: 1; height: 14; color: "#22ffffff" }
                Text { text: "󰸉  Tapeta"; color: "#fff"; font.pixelSize: 14; font.family: Theme.fontUI; font.weight: 700; opacity: 0.9 }
                Item { Layout.fillWidth: true }
                Text { visible: root.loading; text: "skanowanie..."; color: "#88ffffff"; font.pixelSize: 11; font.family: Theme.fontUI }
                Text { visible: !root.loading && root.wallpapers.length > 0; text: root.wallpapers.length + " tapet"; color: "#55ffffff"; font.pixelSize: 11; font.family: Theme.fontUI }
                Rectangle { width: 1; height: 14; color: "#22ffffff"; visible: !root.loading }
                Text { visible: !root.loading; text: "← →  nawigacja   ↵  ustaw   ESC  zamknij"; color: "#33ffffff"; font.pixelSize: 10; font.family: Theme.fontUI }
            }
        }

        // ── Center preview ────────────────────────────────
        Rectangle {
            id: previewCard
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -stripArea.height / 2 - 14
            width: Math.min(parent.width * 0.52, 840)
            height: width * 9 / 16
            radius: 16; clip: true; z: 5; color: "#111"
            border.color: Qt.rgba(
                Qt.color(GlobalState.dynAccent).r,
                                  Qt.color(GlobalState.dynAccent).g,
                                  Qt.color(GlobalState.dynAccent).b, 0.55)
            border.width: 2
            Behavior on border.color { ColorAnimation { duration: 800 } }

            // Scale pulse on preview change
            property int changeCount: 0
            onChangeCountChanged: previewScaleAnim.start()
            SequentialAnimation {
                id: previewScaleAnim
                NumberAnimation { target: previewCard; property: "scale"; to: 0.975; duration: 100; easing.type: Easing.InQuad }
                NumberAnimation { target: previewCard; property: "scale"; to: 1.0; duration: 340; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.45 }
            }

            // Crossfade images — smoother duration
            Image {
                id: imgA
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                smooth: true; asynchronous: true; cache: true
                opacity: 1
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: imgA.width
                        height: imgA.height
                        radius: previewCard.radius
                    }
                }
            }
            Image {
                id: imgB
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                smooth: true; asynchronous: true; cache: true
                opacity: 0
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: imgB.width
                        height: imgB.height
                        radius: previewCard.radius
                    }
                }
            }

            property bool useA: true
            function crossfadeTo(src) {
                previewCard.changeCount++
                if (useA) {
                    imgB.source = src; xfadeBIn.start(); xfadeAOut.start(); useA = false
                } else {
                    imgA.source = src; xfadeAIn.start(); xfadeBOut.start(); useA = true
                }
            }

            NumberAnimation { id: xfadeAIn;  target: imgA; property: "opacity"; to: 1; duration: 450; easing.type: Easing.OutCubic }
            NumberAnimation { id: xfadeAOut; target: imgA; property: "opacity"; to: 0; duration: 450; easing.type: Easing.InCubic }
            NumberAnimation { id: xfadeBIn;  target: imgB; property: "opacity"; to: 1; duration: 450; easing.type: Easing.OutCubic }
            NumberAnimation { id: xfadeBOut; target: imgB; property: "opacity"; to: 0; duration: 450; easing.type: Easing.InCubic }

            // Bottom overlay + info
            Rectangle {
                visible: root.previewName !== ""
                anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                height: 56
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: "#dd000000" }
                }
            }
            RowLayout {
                anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                anchors.margins: 14; anchors.bottomMargin: 10

                Text {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignBottom
                    text: root.previewName; color: "#fff"
                    font.pixelSize: 13; font.family: Theme.fontUI; font.weight: 500; elide: Text.ElideRight
                }
                Rectangle {
                    visible: root.previewPath === root.currentWallpaper
                    Layout.alignment: Qt.AlignBottom
                    height: 22; width: activeLbl.implicitWidth + 14; radius: 11
                    color: GlobalState.dynAccent
                    Behavior on color { ColorAnimation { duration: 800 } }
                    Text { id: activeLbl; anchors.centerIn: parent; text: "✓  aktywna"; color: Theme.bg; font.pixelSize: 10; font.weight: 600 }
                }
            }
        }

        // ── Apply button ──────────────────────────────────
        Rectangle {
            id: applyBtn
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: stripArea.top; anchors.bottomMargin: 18
            height: 40; width: setLbl.implicitWidth + 34; radius: 20; z: 10
            color: setMa.containsMouse ? GlobalState.dynAccent2 : GlobalState.dynAccent

            scale: setMa.pressed ? 0.93 : (setMa.containsMouse ? 1.05 : 1.0)

            Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
            Behavior on scale {
                NumberAnimation {
                    duration: setMa.pressed ? 80 : 300
                    easing.type: setMa.pressed ? Easing.InQuad : Easing.OutElastic
                    easing.amplitude: 1.2; easing.period: 0.38
                }
            }

            Text { id: setLbl; anchors.centerIn: parent; text: "  Ustaw tapetę"; font.pixelSize: 12; font.family: Theme.fontUI; font.weight: 600; color: Theme.bg }
            MouseArea {
                id: setMa; anchors.fill: parent; hoverEnabled: true
                onClicked: { if (root.wallpapers.length > 0) root.applyWallpaper(root.wallpapers[root.previewIndex]) }
            }
        }

        // ── Film strip ────────────────────────────────────
        Item {
            id: stripArea
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
            height: 130; z: 10

            Rectangle { anchors.fill: parent; color: "#000"; opacity: 0.4 }
            Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#22ffffff" }

            ListView {
                id: strip
                anchors.fill: parent
                anchors.topMargin: 12; anchors.bottomMargin: 12
                anchors.leftMargin: 16; anchors.rightMargin: 16
                orientation: ListView.Horizontal; spacing: 8; clip: true
                model: root.wallpapers; focus: true

                onCurrentIndexChanged: {
                    root.previewIndex = currentIndex
                    positionViewAtIndex(currentIndex, ListView.Center)
                }

                Keys.onLeftPressed:  { if (currentIndex > 0) currentIndex-- }
                Keys.onRightPressed: { if (currentIndex < count-1) currentIndex++ }
                Keys.onReturnPressed: { if (root.wallpapers.length > 0) root.applyWallpaper(root.wallpapers[currentIndex]) }
                Keys.onEscapePressed: root.close()

                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AlwaysOff }

                delegate: Item {
                    required property var modelData
                    required property int index
                    property string path:       modelData
                    property bool   isSelected: root.previewIndex === index
                    property bool   isActive:   path === root.currentWallpaper

                    // Spring-expand when selected
                    implicitWidth:  isSelected ? 140 : 106
                    height:         strip.height

                    Behavior on implicitWidth {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutElastic
                            easing.amplitude: 1.1
                            easing.period: 0.42
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.implicitWidth - 4; height: parent.height - 4
                        radius: 10; clip: true; color: "#222"
                        border.color: isActive ? GlobalState.dynAccent : isSelected ? "#66ffffff" : "transparent"
                        border.width: isActive || isSelected ? 2 : 0

                        scale: isSelected ? 1.0 : 0.92

                        Behavior on border.color { ColorAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 280
                                easing.type: Easing.OutElastic
                                easing.amplitude: 1.12
                                easing.period: 0.42
                            }
                        }

                        Image {
                            id: delegateImg
                            anchors.fill: parent
                            source: "file://" + path
                            fillMode: Image.PreserveAspectCrop
                            smooth: true; asynchronous: true; cache: true
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: delegateImg.width
                                    height: delegateImg.height
                                    radius: 10
                                }
                            }
                        }

                        // Darken overlay for non-selected
                        Rectangle {
                            anchors.fill: parent; radius: 10; color: "#000"
                            opacity: isSelected ? 0 : 0.42
                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        }

                        // Active checkmark badge
                        Rectangle {
                            visible: isActive
                            anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 5
                            width: 18; height: 18; radius: 9
                            color: GlobalState.dynAccent
                            Behavior on color { ColorAnimation { duration: 500 } }
                            scale: isActive ? 1.0 : 0.0
                            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutElastic; easing.amplitude: 1.3; easing.period: 0.35 } }
                            Text { anchors.centerIn: parent; text: "✓"; color: Theme.bg; font.pixelSize: 9; font.weight: 700 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onClicked:       { root.previewIndex = index; strip.currentIndex = index }
                        onDoubleClicked: root.applyWallpaper(path)
                    }
                }
            }
        }

        Keys.onLeftPressed:  { if (root.previewIndex > 0) { root.previewIndex--; strip.currentIndex = root.previewIndex } }
        Keys.onRightPressed: { if (root.previewIndex < root.wallpapers.length-1) { root.previewIndex++; strip.currentIndex = root.previewIndex } }
        Keys.onReturnPressed: { if (root.wallpapers.length > 0) root.applyWallpaper(root.wallpapers[root.previewIndex]) }
        Keys.onEscapePressed: root.close()

        // Empty state
        ColumnLayout {
            anchors.centerIn: parent; spacing: 10
            visible: !root.loading && root.wallpapers.length === 0
            Text { Layout.alignment: Qt.AlignHCenter; text: "󰸂"; font.pixelSize: 52; font.family: "JetBrainsMono Nerd Font"; color: "#33ffffff" }
            Text { Layout.alignment: Qt.AlignHCenter; text: "Brak tapet w " + root.wallpaperDir; color: "#66ffffff"; font.pixelSize: 13; font.family: Theme.fontUI }
        }
    }
}
