// ~/.config/quickshell/ClipboardHistory.qml
// Requires: cliphist + wl-clipboard (`yay -S cliphist wl-clipboard`)
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: root
    visible: GlobalState.clipboardOpen || drawer.drawerX < (drawer.width + 2)

    anchors.top: true; anchors.bottom: true; anchors.right: true
    implicitWidth: 380
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.keyboardFocus: GlobalState.clipboardOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: 0

    // ── Data ──────────────────────────────────────────
    property var entries:      []
    property string filterText: ""

    // imgCache: { "entryId": "file:///tmp/qs-clip-ID.img" }
    property var imgCache: ({})

    // Queue of image entry IDs waiting to be decoded
    property var imgQueue: []
    property bool decoding: false

    property var filteredEntries: {
        var q = filterText.toLowerCase().trim()
        if (q === "") return entries
        return entries.filter(function(e) {
            return !e.isImage && (e.preview || "").toLowerCase().includes(q)
        })
    }

    // ── List proc ─────────────────────────────────────
    Process {
        id: listProc
        command: ["cliphist", "list"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var line = data.trim()
                if (line === "") return
                var tabIdx = line.indexOf("\t")
                if (tabIdx < 0) return
                var id      = line.substring(0, tabIdx)
                var preview = line.substring(tabIdx + 1)
                var isImg   = preview.startsWith("[[ binary") || preview.includes("image/png") || preview.includes("image/jpeg") || preview.includes("image/webp")
                root.entries = root.entries.concat([{
                    id:      id,
                    preview: isImg ? "" : preview.substring(0, 300),
                    isImage: isImg
                }])
                if (isImg) {
                    root.imgQueue = root.imgQueue.concat([id])
                }
            }
        }

        onRunningChanged: {
            if (!running) root.processNextImage()
        }
    }

    // ── Sequential image decoder ───────────────────────
    // Decodes ONE image at a time from imgQueue — no fd explosion
    Process {
        id: imgDecodeProc
        property string currentId: ""
        property string outPath: ""
        command: ["sh", "-c", "cliphist decode " + currentId + " > " + outPath + " 2>/dev/null"]
        running: false

        onRunningChanged: {
            if (!running) {
                if (currentId !== "") {
                    // Store in cache
                    var cache = root.imgCache
                    cache[currentId] = "file://" + outPath
                    root.imgCache = cache
                    // Notify list to refresh
                    root.imgCacheChanged()
                }
                root.decoding = false
                root.processNextImage()
            }
        }
    }

    function processNextImage() {
        if (decoding || imgQueue.length === 0) return
        var q = imgQueue.slice()
        var id = q.shift()
        imgQueue = q
        decoding = true
        imgDecodeProc.currentId = id
        imgDecodeProc.outPath   = "/tmp/qs-clip-" + id + ".img"
        imgDecodeProc.running   = false
        imgDecodeProc.running   = true
    }

    // ── Paste proc ────────────────────────────────────
    Process {
        id: pasteProc
        property string entryId: ""
        command: ["sh", "-c", "cliphist decode " + entryId + " | wl-copy"]
        running: false
    }

    Process {
        id: clearProc
        command: ["cliphist", "wipe"]
        running: false
        onRunningChanged: {
            if (!running) Qt.callLater(function() { root.refresh() })
        }
    }

    // ── Refresh ───────────────────────────────────────
    function refresh() {
        root.entries    = []
        root.imgCache   = ({})
        root.imgQueue   = []
        root.decoding   = false
        root.filterText = ""
        listProc.running = false
        listProc.running = true
    }

    function close() { GlobalState.clipboardOpen = false }

    Connections {
        target: GlobalState
        function onClipboardOpenChanged() {
            if (GlobalState.clipboardOpen) root.refresh()
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { GlobalState.clipboardOpen = !GlobalState.clipboardOpen }
        function show(): void   { GlobalState.clipboardOpen = true }
        function hide(): void   { root.close() }
    }

    // ── Backdrop ──────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#000"
        opacity: GlobalState.clipboardOpen ? 0.25 : 0.0
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ── Drawer ────────────────────────────────────────
    Rectangle {
        id: drawer
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.topMargin: 60; anchors.bottomMargin: 8; anchors.rightMargin: 8
        width: 358
        color: Theme.bg; radius: 16
        border.color: Theme.border; border.width: 1
        clip: true

        property real drawerX: GlobalState.clipboardOpen ? 0 : (width + 12)
        transform: Translate { x: drawer.drawerX }
        Behavior on drawerX {
            NumberAnimation {
                duration: GlobalState.clipboardOpen ? 400 : 300
                easing.type: GlobalState.clipboardOpen ? Easing.OutBack : Easing.InCubic
                easing.overshoot: GlobalState.clipboardOpen ? 1.2 : 1.0
            }
        }

        // Top shimmer
        Rectangle {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 1; height: 1; radius: 16
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: "transparent" }
                GradientStop { position: 0.4;  color: Qt.rgba(Qt.color(GlobalState.dynAccent).r, Qt.color(GlobalState.dynAccent).g, Qt.color(GlobalState.dynAccent).b, 0.4) }
                GradientStop { position: 0.6;  color: Qt.rgba(Qt.color(GlobalState.dynAccent).r, Qt.color(GlobalState.dynAccent).g, Qt.color(GlobalState.dynAccent).b, 0.4) }
                GradientStop { position: 1.0;  color: "transparent" }
            }
        }

        ColumnLayout {
            anchors.fill: parent; spacing: 0

            // ── Header ─────────────────────────────────
            Item {
                Layout.fillWidth: true; height: 58

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 14; spacing: 10

                    Text { text: "󰅇"; font.pixelSize: 16; font.family: Theme.fontIcons; color: GlobalState.dynAccent }
                    Text { text: "Historia schowka"; color: Theme.text; font.pixelSize: 14; font.family: Theme.fontDisplay; font.weight: 700; font.letterSpacing: 0.3 }

                    Rectangle {
                        visible: root.entries.length > 0
                        height: 20; width: entCnt.implicitWidth + 10; radius: 10; color: Theme.surface3
                        Text { id: entCnt; anchors.centerIn: parent; text: root.entries.length; color: Theme.muted; font.pixelSize: 10; font.family: Theme.fontUI; font.weight: 600 }
                    }

                    Item { Layout.fillWidth: true }

                    // Clear all
                    Rectangle {
                        width: 28; height: 28; radius: 8
                        color: clearMa.containsMouse ? "#33f87171" : Theme.surface2
                        border.color: clearMa.containsMouse ? Theme.error : Theme.border; border.width: 1
                        scale: clearMa.pressed ? 0.88 : (clearMa.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                        Text { anchors.centerIn: parent; text: "󰃢"; font.pixelSize: 13; font.family: Theme.fontIcons; color: clearMa.containsMouse ? Theme.error : Theme.muted }
                        MouseArea {
                            id: clearMa; anchors.fill: parent; hoverEnabled: true
                            onClicked: { clearProc.running = false; clearProc.running = true }
                        }
                    }

                    // Close
                    Rectangle {
                        width: 28; height: 28; radius: 8
                        color: xMa.containsMouse ? Theme.surface3 : Theme.surface2
                        scale: xMa.pressed ? 0.88 : (xMa.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                        Text { anchors.centerIn: parent; text: "✕"; color: Theme.muted; font.pixelSize: 10 }
                        MouseArea { id: xMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.close() }
                    }
                }

                Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.border; opacity: 0.5 }
            }

            // ── Search ─────────────────────────────────
            Item {
                Layout.fillWidth: true; height: 46

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 14; spacing: 10
                    Text { text: "󰍉"; font.pixelSize: 14; font.family: Theme.fontIcons; color: clipSearch.activeFocus ? GlobalState.dynAccent : Theme.muted; Behavior on color { ColorAnimation { duration: 200 } } }
                    TextInput {
                        id: clipSearch
                        Layout.fillWidth: true
                        text: root.filterText
                        onTextChanged: root.filterText = text
                        color: Theme.text; font.pixelSize: 13; font.family: Theme.fontUI
                        verticalAlignment: TextInput.AlignVCenter; height: parent.height
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Szukaj..."; color: Theme.muted; font.pixelSize: 13; font.family: Theme.fontUI; visible: parent.text === "" }
                        Keys.onEscapePressed: { if (text !== "") text = ""; else root.close() }
                    }
                }

                Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.border; opacity: 0.35 }
            }

            // ── List ───────────────────────────────────
            ListView {
                id: clipList
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; model: root.filteredEntries
                spacing: 0; topMargin: 6; bottomMargin: 6

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 2; radius: 1; color: Theme.accent; opacity: 0.4 }
                    background: null
                }

                // Empty state
                Item {
                    anchors.fill: parent
                    visible: root.entries.length === 0
                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 10
                        Text { Layout.alignment: Qt.AlignHCenter; text: "󰅇"; font.pixelSize: 40; font.family: Theme.fontIcons; color: Theme.surface3 }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "Schowek jest pusty"; color: Theme.muted; font.pixelSize: 12; font.family: Theme.fontUI }
                    }
                }

                delegate: Item {
                    id: cDel
                    required property var modelData
                    required property int index

                    // imgSrc read from root-level cache — no process spawning in delegate
                    property string imgSrc: modelData.isImage ? (root.imgCache[modelData.id] || "") : ""

                    // Re-evaluate imgSrc whenever cache is updated
                    Connections {
                        target: root
                        function onImgCacheChanged() {
                            cDel.imgSrc = modelData.isImage ? (root.imgCache[modelData.id] || "") : ""
                        }
                    }

                    width: clipList.width
                    height: modelData.isImage ? 110 : Math.min(previewTxt.implicitHeight + 32, 90)

                    // Stagger fade-in — only runs once on creation, not on recycle
                    opacity: 0
                    NumberAnimation on opacity {
                        id: cFade; from: 0; to: 1; running: false
                        duration: 180; easing.type: Easing.OutQuad
                    }
                    Timer {
                        interval: Math.min(cDel.index * 18, 300)
                        running: true; repeat: false
                        onTriggered: cFade.start()
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        anchors.topMargin: 3; anchors.bottomMargin: 3
                        radius: 10
                        color: cItemMa.containsMouse ? Theme.surface : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        // ── Image entry ─────────────────
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10
                            spacing: 12
                            visible: cDel.modelData.isImage

                            Rectangle {
                                width: 80; height: 80; radius: 8
                                color: Theme.surface2; clip: true
                                border.color: Theme.border; border.width: 1

                                Image {
                                    id: thumbImg
                                    anchors.fill: parent
                                    source: cDel.imgSrc
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true; asynchronous: true
                                    opacity: status === Image.Ready ? 1.0 : 0
                                    Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutQuad } }
                                }

                                // Placeholder while loading
                                Text {
                                    anchors.centerIn: parent; text: "󰸉"
                                    font.pixelSize: 26; font.family: Theme.fontIcons; color: Theme.muted
                                    visible: thumbImg.status !== Image.Ready
                                }
                            }

                            ColumnLayout { Layout.fillWidth: true; spacing: 5
                                Text { text: "Obraz"; color: GlobalState.dynAccent; font.pixelSize: 12; font.family: Theme.fontUI; font.weight: 700 }
                                Text {
                                    text: cDel.imgSrc !== "" ? "Kliknij aby skopiować" : "Dekodowanie..."
                                    color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontUI
                                }
                            }
                        }

                        // ── Text entry ──────────────────
                        Item {
                            anchors.fill: parent; anchors.margins: 12
                            visible: !cDel.modelData.isImage

                            Text {
                                id: previewTxt
                                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                text: cDel.modelData.preview || ""
                                color: Theme.subtext; font.pixelSize: 12; font.family: Theme.fontMono
                                wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                                lineHeight: 1.35
                            }
                        }

                        // Hover badge
                        Rectangle {
                            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                            height: 20; width: copyLbl.implicitWidth + 12; radius: 10
                            color: Theme.surface3; border.color: Theme.border; border.width: 1
                            opacity: cItemMa.containsMouse ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                            Text { id: copyLbl; anchors.centerIn: parent; text: "Kopiuj"; color: Theme.muted; font.pixelSize: 10; font.family: Theme.fontUI }
                        }
                    }

                    MouseArea {
                        id: cItemMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            pasteProc.entryId = cDel.modelData.id
                            pasteProc.running = false
                            pasteProc.running = true
                            root.close()
                        }
                    }
                }
            }
        }
    }
}
