// ~/.config/quickshell/Launcher.qml
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

PanelWindow {
    id: root
    visible: GlobalState.launcherOpen || win.winOpacity > 0.005

    anchors.top: true; anchors.bottom: true
    anchors.left: true; anchors.right: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: GlobalState.launcherOpen
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string terminal: "kitty"

    function launchEntry(entry) {
        if (!entry) return

        if (entry.runInTerminal && entry.command.length > 0) {
            // Apki terminalowe: prepend terminal -e przed sparsowaną komendą
            Quickshell.execDetached({
                command: [root.terminal, "-e"].concat(entry.command),
                workingDirectory: entry.workingDirectory
            })
        } else {
            // Wszystkie inne: użyj entry.command (sparsowana tablica, nie surowy exec string)
            Quickshell.execDetached({
                command: entry.command,
                workingDirectory: entry.workingDirectory
            })
        }

        root.close()
    }

    function open() {
        searchInput.text = ""
        searchInput.forceActiveFocus()
        appGrid.currentIndex = -1
    }
    function close() { GlobalState.launcherOpen = false }

    Connections {
        target: GlobalState
        function onLauncherOpenChanged() {
            if (GlobalState.launcherOpen) root.open()
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { GlobalState.launcherOpen = !GlobalState.launcherOpen }
        function show(): void   { GlobalState.launcherOpen = true }
        function hide(): void   { root.close() }
    }

    property var allApps: {
        var arr = []
        var vals = DesktopEntries.applications.values
        for (var i = 0; i < vals.length; i++) {
            var e = vals[i]
            if (e && e.name && e.name !== "") arr.push(e)
        }
        arr.sort(function(a, b) { return (a.name || "").localeCompare(b.name || "") })
        return arr
    }

    ScriptModel {
        id: filteredModel
        values: {
            var q = searchInput.text.toLowerCase().trim()
            if (q === "") return root.allApps
            return root.allApps.filter(function(e) {
                return (e.name || "").toLowerCase().includes(q) ||
                       (e.genericName || "").toLowerCase().includes(q) ||
                       (e.comment || "").toLowerCase().includes(q) ||
                       (e.id || "").toLowerCase().includes(q)
            })
        }
    }

    property bool isSearching: searchInput.text !== ""

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: "#000"
        opacity: GlobalState.launcherOpen ? 0.62 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: GlobalState.launcherOpen ? 300 : 250; easing.type: Easing.OutCubic }
        }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // Panel wrapper for animation
    Item {
        id: win
        anchors.centerIn: parent
        width: 700
        height: contentCol.implicitHeight + 2
        property real winOpacity: GlobalState.launcherOpen ? 1.0 : 0.0
        property real winScale:   GlobalState.launcherOpen ? 1.0 : 0.93
        property real winSlide:   GlobalState.launcherOpen ? 0.0 : -18.0

        opacity: winOpacity
        scale:   winScale
        transform: Translate { y: win.winSlide }

        Behavior on winOpacity { NumberAnimation { duration: GlobalState.launcherOpen ? 300 : 240; easing.type: GlobalState.launcherOpen ? Easing.OutCubic : Easing.InQuad } }
        Behavior on winScale   { NumberAnimation { duration: GlobalState.launcherOpen ? 440 : 240; easing.type: GlobalState.launcherOpen ? Easing.OutElastic : Easing.InQuad; easing.amplitude: 1.06; easing.period: 0.5 } }
        Behavior on winSlide   { NumberAnimation { duration: GlobalState.launcherOpen ? 380 : 240; easing.type: GlobalState.launcherOpen ? Easing.OutCubic : Easing.InQuad } }

        // Glass background
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            radius: 20
            border.color: Theme.border
            border.width: 1

            // Top gradient glow bar
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: 340; height: 1; radius: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0;  color: "transparent" }
                    GradientStop { position: 0.35; color: Qt.rgba(Qt.color(GlobalState.dynAccent).r, Qt.color(GlobalState.dynAccent).g, Qt.color(GlobalState.dynAccent).b, 0.6) }
                    GradientStop { position: 0.65; color: Qt.rgba(Qt.color(GlobalState.dynAccent).r, Qt.color(GlobalState.dynAccent).g, Qt.color(GlobalState.dynAccent).b, 0.6) }
                    GradientStop { position: 1.0;  color: "transparent" }
                }
            }
        }

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            // ── SEARCH ─────────────────────────────────
            Item {
                Layout.fillWidth: true
                height: 70

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 22; anchors.rightMargin: 18
                    spacing: 14

                    Text {
                        text: "󰍉"
                        font.pixelSize: 20; font.family: Theme.fontIcons
                        color: searchInput.activeFocus ? GlobalState.dynAccent : Theme.muted
                        scale: searchInput.activeFocus ? 1.0 : 0.88
                        rotation: searchInput.activeFocus ? 0 : -10
                        Behavior on color    { ColorAnimation { duration: 250 } }
                        Behavior on scale    { NumberAnimation { duration: 300; easing.type: Easing.OutElastic; easing.amplitude: 1.3; easing.period: 0.38 } }
                        Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.4 } }
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: Theme.text
                        font.pixelSize: 17; font.family: Theme.fontDisplay; font.weight: 500; font.letterSpacing: 0.2
                        verticalAlignment: TextInput.AlignVCenter
                        height: parent.height
                        selectionColor: Qt.rgba(Qt.color(GlobalState.dynAccent).r, Qt.color(GlobalState.dynAccent).g, Qt.color(GlobalState.dynAccent).b, 0.3)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Szukaj aplikacji..."
                            color: Theme.muted; font.pixelSize: 17; font.family: Theme.fontDisplay; font.weight: 400
                            visible: parent.text === ""
                        }

                        Keys.onEscapePressed: { if (text !== "") text = ""; else root.close() }
                        Keys.onReturnPressed: {
                            if (filteredModel.values.length > 0)
                                root.launchEntry(filteredModel.values[root.isSearching ? (resultList.currentIndex >= 0 ? resultList.currentIndex : 0) : (appGrid.currentIndex >= 0 ? appGrid.currentIndex : 0)])
                        }
                        Keys.onDownPressed: {
                            if (root.isSearching) { resultList.forceActiveFocus(); resultList.currentIndex = 0 }
                            else { appGrid.forceActiveFocus(); appGrid.currentIndex = 0 }
                        }
                    }

                    Rectangle {
                        visible: filteredModel.values.length > 0 && root.isSearching
                        height: 22; width: cntTxt.implicitWidth + 14; radius: 11; color: Theme.surface3
                        Text { id: cntTxt; anchors.centerIn: parent; text: filteredModel.values.length; color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontUI; font.weight: 600 }
                    }
                }

                // Animated gradient underline
                Rectangle {
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    height: 1
                    width: searchInput.activeFocus ? parent.width - 28 : parent.width * 0.42
                    radius: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0;  color: "transparent" }
                        GradientStop { position: 0.3;  color: Qt.rgba(Qt.color(GlobalState.dynAccent).r, Qt.color(GlobalState.dynAccent).g, Qt.color(GlobalState.dynAccent).b, searchInput.activeFocus ? 0.60 : 0.18) }
                        GradientStop { position: 0.7;  color: Qt.rgba(Qt.color(GlobalState.dynAccent).r, Qt.color(GlobalState.dynAccent).g, Qt.color(GlobalState.dynAccent).b, searchInput.activeFocus ? 0.60 : 0.18) }
                        GradientStop { position: 1.0;  color: "transparent" }
                    }
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                }
            }

            // ── GRID (empty search) ─────────────────────
            GridView {
                id: appGrid
                Layout.fillWidth: true
                Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 6; Layout.bottomMargin: 14
                implicitHeight: Math.min(contentHeight, 420)
                height: implicitHeight
                visible: !root.isSearching
                clip: true; model: filteredModel; currentIndex: -1; keyNavigationEnabled: true

                property int cols: 5
                cellWidth: Math.floor((width) / cols)
                cellHeight: 110

                Behavior on implicitHeight { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                Keys.onEscapePressed: { searchInput.forceActiveFocus(); currentIndex = -1 }
                Keys.onReturnPressed: { if (currentIndex >= 0) root.launchEntry(filteredModel.values[currentIndex]) }
                Keys.onUpPressed:     { if (currentIndex < cols) { searchInput.forceActiveFocus(); currentIndex = -1 } else moveCurrentIndexUp() }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 2; radius: 1; color: Theme.accent; opacity: 0.4 }
                    background: null
                }

                delegate: Item {
                    id: gDel
                    required property var modelData
                    required property int index
                    property bool isSelected: appGrid.currentIndex === index

                    width: appGrid.cellWidth; height: appGrid.cellHeight

                    opacity: 0; scale: 0.82
                    NumberAnimation on opacity { id: gFadeIn; from: 0; to: 1; running: false; duration: 200; easing.type: Easing.OutQuad }
                    NumberAnimation on scale   { id: gScaleIn; from: 0.82; to: 1.0; running: false; duration: 270; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                    Timer { interval: Math.min(gDel.index * 15, 360); running: true; onTriggered: { gFadeIn.start(); gScaleIn.start() } }

                    Rectangle {
                        anchors.fill: parent; anchors.margins: 6; radius: 14
                        color: gDel.isSelected
                            ? Qt.rgba(Qt.color(GlobalState.dynAccent).r, Qt.color(GlobalState.dynAccent).g, Qt.color(GlobalState.dynAccent).b, 0.15)
                            : gMa.containsMouse ? Theme.surface2 : "transparent"
                        border.color: gDel.isSelected
                            ? Qt.rgba(Qt.color(GlobalState.dynAccent).r, Qt.color(GlobalState.dynAccent).g, Qt.color(GlobalState.dynAccent).b, 0.5)
                            : "transparent"
                        border.width: 1
                        scale: gDel.isSelected ? 1.07 : (gMa.containsMouse ? 1.04 : 1.0)
                        Behavior on color  { ColorAnimation { duration: 140 } }
                        Behavior on scale  { NumberAnimation { duration: 250; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.42 } }

                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 8

                            Item {
                                Layout.alignment: Qt.AlignHCenter; width: 52; height: 52
                                IconImage { id: gIcon; anchors.fill: parent; source: Quickshell.iconPath(gDel.modelData.icon || "", true); smooth: true }
                                Rectangle {
                                    anchors.fill: parent; radius: 14; visible: gIcon.status !== Image.Ready
                                    color: Qt.rgba(Qt.color(GlobalState.dynAccent).r, Qt.color(GlobalState.dynAccent).g, Qt.color(GlobalState.dynAccent).b, 0.14)
                                    border.color: Theme.border; border.width: 1
                                    Text { anchors.centerIn: parent; text: (gDel.modelData.name || "?")[0].toUpperCase(); color: GlobalState.dynAccent; font.pixelSize: 20; font.family: Theme.fontDisplay; font.weight: 700 }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: appGrid.cellWidth - 16
                                text: gDel.modelData.name || ""
                                color: gDel.isSelected ? Theme.text : Theme.subtext
                                font.pixelSize: 11; font.family: Theme.fontUI; font.weight: 600
                                elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                        }
                    }

                    MouseArea { id: gMa; anchors.fill: parent; hoverEnabled: true; onEntered: appGrid.currentIndex = index; onClicked: root.launchEntry(gDel.modelData) }
                }
            }

            // ── LIST (search results) ───────────────────
            ListView {
                id: resultList
                Layout.fillWidth: true
                Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.topMargin: 6; Layout.bottomMargin: 12
                implicitHeight: Math.min(count * 56, 480)
                height: implicitHeight
                visible: root.isSearching
                clip: true; model: filteredModel; currentIndex: 0; keyNavigationEnabled: true

                Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Keys.onEscapePressed: { searchInput.forceActiveFocus(); currentIndex = -1 }
                Keys.onReturnPressed: { if (currentIndex >= 0) root.launchEntry(filteredModel.values[currentIndex]) }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 2; radius: 1; color: Theme.accent; opacity: 0.4 }
                    background: null
                }

                delegate: Item {
                    id: lDel
                    required property var modelData
                    required property int index
                    property bool isSelected: resultList.currentIndex === index

                    width: resultList.width; height: 56

                    opacity: 0
                    NumberAnimation on opacity { id: lFade; from: 0; to: 1; running: false; duration: 160; easing.type: Easing.OutQuad }
                    Timer { interval: Math.min(lDel.index * 20, 260); running: true; onTriggered: lFade.start() }

                    Rectangle {
                        anchors.fill: parent; anchors.leftMargin: 2; anchors.rightMargin: 2; radius: 10
                        color: lDel.isSelected
                            ? Qt.rgba(Qt.color(GlobalState.dynAccent).r, Qt.color(GlobalState.dynAccent).g, Qt.color(GlobalState.dynAccent).b, 0.13)
                            : lMa.containsMouse ? Theme.surface : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        // Left accent strip
                        Rectangle {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 7; width: 3; radius: 2
                            height: lDel.isSelected ? 26 : 0
                            color: GlobalState.dynAccent
                            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                        }

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 12; spacing: 12

                            Item { width: 34; height: 34
                                IconImage { id: lIcon; anchors.fill: parent; smooth: true; source: Quickshell.iconPath(lDel.modelData.icon || "", true) }
                                Rectangle {
                                    anchors.fill: parent; radius: 9; visible: lIcon.status !== Image.Ready
                                    color: Qt.rgba(Qt.color(GlobalState.dynAccent).r, Qt.color(GlobalState.dynAccent).g, Qt.color(GlobalState.dynAccent).b, 0.14)
                                    border.color: Theme.border; border.width: 1
                                    Text { anchors.centerIn: parent; text: (lDel.modelData.name || "?")[0].toUpperCase(); color: GlobalState.dynAccent; font.pixelSize: 13; font.family: Theme.fontDisplay; font.weight: 700 }
                                }
                            }

                            ColumnLayout { Layout.fillWidth: true; spacing: 2
                                Text {
                                    Layout.fillWidth: true; text: lDel.modelData.name || ""
                                    color: lDel.isSelected ? Theme.text : Theme.subtext
                                    font.pixelSize: 13; font.family: Theme.fontUI; font.weight: 700; elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: lDel.modelData.genericName || lDel.modelData.comment || ""
                                    color: Theme.muted; font.pixelSize: 11; font.family: Theme.fontUI
                                    elide: Text.ElideRight; visible: text !== ""
                                }
                            }

                            Rectangle {
                                visible: lDel.isSelected; height: 22; width: 28; radius: 6
                                color: Theme.surface2; border.color: Theme.border; border.width: 1
                                Text { anchors.centerIn: parent; text: "↵"; color: GlobalState.dynAccent; font.pixelSize: 11 }
                            }
                        }
                    }

                    MouseArea { id: lMa; anchors.fill: parent; hoverEnabled: true; onEntered: resultList.currentIndex = index; onClicked: root.launchEntry(lDel.modelData) }
                }
            }

            // No results
            Item {
                Layout.fillWidth: true; height: 80; Layout.bottomMargin: 8
                visible: root.isSearching && filteredModel.values.length === 0
                ColumnLayout { anchors.centerIn: parent; spacing: 8
                    Text { Layout.alignment: Qt.AlignHCenter; text: "󰍉"; font.pixelSize: 30; font.family: Theme.fontIcons; color: Theme.surface3 }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Brak wyników"; color: Theme.muted; font.pixelSize: 12; font.family: Theme.fontUI }
                }
            }
        }
    }
}
