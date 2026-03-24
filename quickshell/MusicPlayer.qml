// ~/.config/quickshell/MusicPlayer.qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    property MprisPlayer player: {
        var pl = Mpris.players.values
        if (!pl || pl.length === 0) return null
        for (var i = 0; i < pl.length; i++) {
            if (pl[i] && pl[i].identity && pl[i].identity.toLowerCase().includes("spotify"))
                return pl[i]
        }
        for (var i = 0; i < pl.length; i++) {
            var id = pl[i] ? (pl[i].identity || "").toLowerCase() : ""
            if (id.includes("chrom") || id.includes("firefox") || id.includes("zen") || id.includes("brave"))
                return pl[i]
        }
        return pl[0] || null
    }

    property bool hasWindows: {
        var fw = Hyprland.focusedWorkspace
        if (!fw) return false
        var tl = fw.toplevels
        return tl && tl.values && tl.values.length > 0
    }

    property bool shouldShow: player !== null
        && (player.trackTitle || "") !== ""
        && !hasWindows

    // Keep window alive during hide animation
    visible: shouldShow || playerCard.cardOpacity > 0.005

    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 90
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-music"
    WlrLayershell.exclusiveZone: 0

    FrameAnimation {
        running: root.player !== null
            && root.player.playbackState === MprisPlaybackState.Playing
        onTriggered: { if (root.player) root.player.positionChanged() }
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: playerCard
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            width: playerRow.implicitWidth + 32
            height: 74
            color: Theme.surface
            radius: 14
            border.color: Theme.border
            border.width: 1
            clip: true

            // ── Show / hide animation ──────────────────
            property real cardOpacity: root.shouldShow ? 1.0 : 0.0
            property real cardSlide:   root.shouldShow ? 0.0 : 20.0

            opacity: cardOpacity
            transform: Translate { y: playerCard.cardSlide }

            Behavior on cardOpacity {
                NumberAnimation {
                    duration: root.shouldShow ? 380 : 280
                    easing.type: root.shouldShow ? Easing.OutCubic : Easing.InQuad
                }
            }
            Behavior on cardSlide {
                NumberAnimation {
                    duration: root.shouldShow ? 420 : 280
                    easing.type: root.shouldShow ? Easing.OutBack : Easing.InCubic
                    easing.overshoot: 1.3
                }
            }

            // Background art blur
            Image {
                anchors.fill: parent
                source: root.player ? (root.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                opacity: 0.1; visible: status === Image.Ready
                Behavior on opacity { NumberAnimation { duration: 400 } }
            }

            RowLayout {
                id: playerRow
                anchors.centerIn: parent
                spacing: 14

                // Album art — scale bounce on track change
                Rectangle {
                    id: artRect
                    width: 48; height: 48; radius: 10
                    color: Theme.surface2; clip: true

                    property string currentSrc: root.player ? (root.player.trackArtUrl || "") : ""
                    onCurrentSrcChanged: {
                        artBounce.start()
                    }

                    SequentialAnimation {
                        id: artBounce
                        NumberAnimation { target: artRect; property: "scale"; to: 0.82; duration: 110; easing.type: Easing.InQuad }
                        NumberAnimation { target: artRect; property: "scale"; to: 1.0; duration: 320; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.4 }
                    }

                    Image {
                        id: art; anchors.fill: parent
                        source: root.player ? (root.player.trackArtUrl || "") : ""
                        fillMode: Image.PreserveAspectCrop
                        Behavior on source {
                            SequentialAnimation {
                                NumberAnimation { target: art; property: "opacity"; to: 0; duration: 100 }
                                NumberAnimation { target: art; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutQuad }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent; text: "♪"
                        font.pixelSize: 20; color: Theme.accent
                        visible: art.status !== Image.Ready
                    }
                }

                ColumnLayout {
                    spacing: 4

                    Text {
                        text: root.player ? (root.player.trackTitle || "—") : "—"
                        color: Theme.text; font.pixelSize: 13
                        font.family: "CaskaydiaCove Nerd Font"; font.weight: 600
                        elide: Text.ElideRight; Layout.maximumWidth: 200

                        Behavior on text {
                            SequentialAnimation {
                                NumberAnimation { target: parent; property: "opacity"; to: 0; duration: 80 }
                                NumberAnimation { target: parent; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuad }
                            }
                        }
                    }

                    Text {
                        text: root.player ? (root.player.trackArtist || "") : ""
                        color: Theme.subtext; font.pixelSize: 11
                        font.family: "CaskaydiaCove Nerd Font"
                        elide: Text.ElideRight; Layout.maximumWidth: 200
                    }

                    // Progress bar — gradient + smooth
                    Item {
                        width: 200; height: 4

                        Rectangle { anchors.fill: parent; color: Theme.surface3; radius: 2 }

                        Rectangle {
                            property real prog: {
                                if (!root.player) return 0
                                var len = root.player.length
                                return (len && len > 0) ? root.player.position / len : 0
                            }
                            width: Math.max(4, parent.width * prog)
                            height: parent.height; radius: 2

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Theme.accent }
                                GradientStop { position: 1.0; color: Theme.accent2 }
                            }

                            Behavior on width { SmoothedAnimation { duration: 450; velocity: -1; easing.type: Easing.OutCubic } }

                            // Thumb
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right; anchors.rightMargin: -3
                                width: 6; height: 6; radius: 3
                                color: Theme.accent2; border.color: Theme.surface; border.width: 1
                            }
                        }
                    }
                }

                Rectangle { width: 1; height: 36; color: Theme.border; opacity: 0.5 }

                RowLayout {
                    spacing: 2
                    MediaBtn { btnText: "⏮"; onActivated: { if (root.player) root.player.previous() } }
                    MediaBtn {
                        btnText: root.player && root.player.playbackState === MprisPlaybackState.Playing ? "⏸" : "▶"
                        fontSize: 16
                        onActivated: { if (root.player) root.player.togglePlaying() }
                    }
                    MediaBtn { btnText: "⏭"; onActivated: { if (root.player) root.player.next() } }
                    MediaBtn {
                        btnText: "⇄"; active: root.player ? root.player.shuffle : false
                        onActivated: { if (root.player) root.player.shuffle = !root.player.shuffle }
                    }
                }
            }
        }
    }
}
