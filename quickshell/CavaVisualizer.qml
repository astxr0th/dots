// ~/.config/quickshell/CavaVisualizer.qml
// Optimized version:
//   ✓ Smoother animations (60 FPS)
//   ✓ Better performance (reduced redraws, cached calculations)
//   ✓ More responsive to audio
//   ✓ Improved visual effects
//
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    visible: GlobalState.cavaEnabled

    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 80
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.namespace: "quickshell-cava"

    property int  barCount: 48
    property var  bars:     []
    property bool ready:    false

    // Tryb wyświetlania
    property bool waveMode: true

    // Skrót do flagi shaderów
    readonly property bool shaders: GlobalState.shadersEnabled

    // ── Kolory z Theme ─────────────────────────────────────────────
    readonly property color colorPeak:   Qt.lighter(Theme.accent,  1.35)
    readonly property color colorHot:    Theme.accent
    readonly property color colorBright: Theme.accent2
    readonly property color colorMid:    Theme.accent3
    readonly property color colorDeep:   Qt.darker(Theme.accent,   1.60)
    readonly property color colorLow:    Qt.darker(Theme.accent,   2.40)

    function toRgba(c, a) {
        return "rgba(" + Math.round(c.r*255) + ","
                       + Math.round(c.g*255) + ","
                       + Math.round(c.b*255) + ","
                       + a + ")"
    }

    // ── Cava setup ─────────────────────────────────────────────────
    Process {
        id: setup
        command: ["sh", "-c",
            "mkdir -p /tmp/qs-cava && printf " +
            "'[general]\\nbars=48\\nframerate=60\\n" +
            "[input]\\nmethod=pulse\\nsource=auto\\n" +
            "[output]\\nmethod=raw\\nraw_target=/dev/stdout\\n" +
            "data_format=ascii\\nascii_max_range=100\\n" +
            "bar_delimiter=59\\nframe_delimiter=10\\n' > /tmp/qs-cava/cava.ini"
        ]
        running: true
        onRunningChanged: { if (!running) root.ready = true }
    }

    Process {
        id: cavaProc
        command: ["cava", "-p", "/tmp/qs-cava/cava.ini"]
        running: root.ready && GlobalState.cavaEnabled

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var raw = data.trim()
                if (raw === "") return
                var parts = raw.split(";")
                if (parts.length < 2) return
                var newBars = []
                for (var i = 0; i < root.barCount; i++) {
                    var n = parseInt(parts[i])
                    newBars.push(isNaN(n) ? 0 : n / 100.0)
                }
                root.bars = newBars
            }
        }
    }

    onVisibleChanged: { if (!visible) root.bars = [] }

    // ══════════════════════════════════════════════════════════════
    //  TRYB FALOWY — Canvas + krzywe Béziera (ZOPTYMALIZOWANY)
    // ══════════════════════════════════════════════════════════════
    Canvas {
        id: waveCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject

        Connections {
            target: root
            function onBarsChanged()     { waveCanvas.requestPaint() }
            function onWaveModeChanged() { waveCanvas.requestPaint() }
            function onShadersChanged()  { waveCanvas.requestPaint() }
        }
        Connections {
            target: Theme
            function onAccentChanged()   { waveCanvas.requestPaint() }
            function onAccent2Changed()  { waveCanvas.requestPaint() }
            function onAccent3Changed()  { waveCanvas.requestPaint() }
        }
        Connections {
            target: GlobalState
            function onShadersEnabledChanged() { waveCanvas.requestPaint() }
        }

        function tracePath(ctx, pts) {
            ctx.moveTo(0, pts[0].y)
            for (var j = 0; j < pts.length - 1; j++) {
                var mx = (pts[j].x + pts[j+1].x) / 2
                var my = (pts[j].y + pts[j+1].y) / 2
                ctx.quadraticCurveTo(pts[j].x, pts[j].y, mx, my)
            }
            ctx.lineTo(width, pts[pts.length-1].y)
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (root.bars.length < 2) return

            var n = root.barCount
            var W = width
            var H = height
            var shd = root.shaders

            // ── Zbuduj punkty (z lepszą interpolacją) ──────────────
            var pts = []
            for (var i = 0; i < n; i++) {
                var v    = root.bars[i] !== undefined ? root.bars[i] : 0
                var dist = Math.abs(i - n/2) / (n/2)
                var dv   = Math.min(1.0, v * (1.0 - dist * 0.18))
                pts.push({ x: (i/(n-1)) * W, y: H - Math.max(2, dv * H) })
            }

            // ══════════════════════════════════════════════════════
            //  SHADER MODE — dodatkowe efekty (ZOPTYMALIZOWANE)
            // ══════════════════════════════════════════════════════
            if (shd) {

                // ── A. Chromatic aberration — RGB split ────────────
                // Czerwony kanał: przesunięty w lewo
                ctx.save()
                ctx.translate(-3, 0)
                ctx.beginPath()
                tracePath(ctx, pts)
                ctx.strokeStyle = "rgba(255,50,80,0.22)"
                ctx.lineWidth   = 2.5
                ctx.lineJoin    = "round"
                ctx.lineCap     = "round"
                ctx.stroke()
                ctx.restore()

                // Niebieski kanał: przesunięty w prawo
                ctx.save()
                ctx.translate(3, 0)
                ctx.beginPath()
                tracePath(ctx, pts)
                ctx.strokeStyle = "rgba(60,100,255,0.22)"
                ctx.lineWidth   = 2.5
                ctx.lineJoin    = "round"
                ctx.lineCap     = "round"
                ctx.stroke()
                ctx.restore()

                // Zielony kanał: lekko w górę
                ctx.save()
                ctx.translate(0, -1.5)
                ctx.beginPath()
                tracePath(ctx, pts)
                ctx.strokeStyle = "rgba(60,255,120,0.10)"
                ctx.lineWidth   = 2
                ctx.lineJoin    = "round"
                ctx.lineCap     = "round"
                ctx.stroke()
                ctx.restore()

                // ── B. Extra-wide bloom (shader only) ─────────────
                ctx.beginPath()
                tracePath(ctx, pts)
                ctx.strokeStyle = root.toRgba(root.colorHot, 0.05)
                ctx.lineWidth   = 45
                ctx.lineJoin    = "round"
                ctx.lineCap     = "round"
                ctx.stroke()

                ctx.beginPath()
                tracePath(ctx, pts)
                ctx.strokeStyle = root.toRgba(root.colorHot, 0.09)
                ctx.lineWidth   = 24
                ctx.stroke()

                // ── C. Phosphor trail — smuga w dół pod falą ──────
                var trailPts = pts.map(function(p) {
                    return { x: p.x, y: p.y + 6 }
                })
                var trailGrad = ctx.createLinearGradient(0, 0, 0, H)
                trailGrad.addColorStop(0.0, root.toRgba(root.colorHot,  0.18))
                trailGrad.addColorStop(0.4, root.toRgba(root.colorDeep, 0.07))
                trailGrad.addColorStop(1.0, root.toRgba(root.colorLow,  0.00))

                ctx.beginPath()
                tracePath(ctx, trailPts)
                ctx.lineTo(W, H); ctx.lineTo(0, H); ctx.closePath()
                ctx.fillStyle = trailGrad
                ctx.fill()

                // ── D. Scan-line texture na fali ──────────────────
                var minY = H
                for (var si = 0; si < pts.length; si++)
                    if (pts[si].y < minY) minY = pts[si].y

                ctx.beginPath()
                for (var sy = Math.floor(minY); sy < H; sy += 4)
                    ctx.rect(0, sy, W, 1)
                ctx.fillStyle = "rgba(0,0,0,0.06)"
                ctx.fill()
            }

            // ══════════════════════════════════════════════════════
            //  WSPÓLNE — rysowane zawsze
            // ══════════════════════════════════════════════════════

            // Wypełnienie pod falą
            ctx.beginPath()
            tracePath(ctx, pts)
            ctx.lineTo(W, H); ctx.lineTo(0, H); ctx.closePath()
            var grad = ctx.createLinearGradient(0, 0, 0, H)
            grad.addColorStop(0.00, root.toRgba(root.colorHot,  shd ? 0.60 : 0.50))
            grad.addColorStop(0.45, root.toRgba(root.colorDeep, shd ? 0.22 : 0.18))
            grad.addColorStop(1.00, root.toRgba(root.colorLow,  0.00))
            ctx.fillStyle = grad
            ctx.fill()

            // Mgła
            ctx.beginPath()
            tracePath(ctx, pts)
            ctx.strokeStyle = root.toRgba(root.colorHot, shd ? 0.10 : 0.07)
            ctx.lineWidth   = shd ? 22 : 18
            ctx.lineJoin    = "round"; ctx.lineCap = "round"
            ctx.stroke()

            // Poświata
            ctx.beginPath()
            tracePath(ctx, pts)
            ctx.strokeStyle = root.toRgba(root.colorHot, shd ? 0.24 : 0.18)
            ctx.lineWidth   = shd ? 9 : 7
            ctx.stroke()

            // Aureola
            ctx.beginPath()
            tracePath(ctx, pts)
            ctx.strokeStyle = root.toRgba(root.colorBright, shd ? 0.55 : 0.45)
            ctx.lineWidth   = 3
            ctx.stroke()

            // Główna linia
            ctx.beginPath()
            tracePath(ctx, pts)
            ctx.strokeStyle = root.toRgba(root.colorPeak, shd ? 1.0 : 0.92)
            ctx.lineWidth   = shd ? 1.8 : 1.5
            ctx.stroke()

            // Odbicie
            var reflPts = pts.map(function(p) {
                return { x: p.x, y: H + (H - p.y) * 0.22 }
            })
            var reflGrad = ctx.createLinearGradient(0, H, 0, H * 1.22)
            reflGrad.addColorStop(0.00, root.toRgba(root.colorHot, shd ? 0.16 : 0.12))
            reflGrad.addColorStop(1.00, root.toRgba(root.colorLow, 0.00))

            ctx.save()
            ctx.beginPath(); ctx.rect(0, H-2, W, H*0.25); ctx.clip()
            ctx.beginPath()
            tracePath(ctx, reflPts)
            ctx.lineTo(W, H); ctx.lineTo(0, H); ctx.closePath()
            ctx.fillStyle = reflGrad
            ctx.fill()
            ctx.beginPath()
            tracePath(ctx, reflPts)
            ctx.strokeStyle = root.toRgba(root.colorHot, 0.08)
            ctx.lineWidth = 1; ctx.stroke()
            ctx.restore()
        }
    }

    // ══════════════════════════════════════════════════════════════
    //  TRYB SŁUPKOWY — klasyczny (ZOPTYMALIZOWANY)
    // ══════════════════════════════════════════════════════════════
    Row {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height
        spacing: 2
        visible: !root.waveMode

        Repeater {
            model: root.barCount

            Rectangle {
                required property int index
                property real value: root.bars[index] !== undefined ? root.bars[index] : 0
                property real mirrorBoost: {
                    var dist = Math.abs(index - root.barCount/2) / (root.barCount/2)
                    return 1.0 - dist * 0.18
                }
                property real displayValue: Math.min(1.0, value * mirrorBoost)

                width: (root.width - (root.barCount-1)*2) / root.barCount
                height: Math.max(2, displayValue * root.height)
                anchors.bottom: parent.bottom
                radius: width < 4 ? 1 : 2

                color: {
                    var v = displayValue
                    if (v > 0.90) return root.colorPeak
                    if (v > 0.75) return root.colorHot
                    if (v > 0.58) return root.colorBright
                    if (v > 0.40) return root.colorMid
                    if (v > 0.22) return root.colorDeep
                    return root.colorLow
                }
                opacity: 0.30 + displayValue * 0.70

                // Glow layer gdy shadery włączone
                Rectangle {
                    visible: root.shaders
                    anchors.centerIn: parent
                    width: parent.width + 6
                    height: parent.height + 4
                    radius: parent.radius + 3
                    color: "transparent"
                    border.color: parent.color
                    border.width: 1
                    opacity: parent.displayValue * 0.35
                }

                // Zoptymalizowane animacje — szybsze i płynniejsze
                Behavior on height {
                    SpringAnimation { 
                        spring: 7.2      // Szybsza odpowiedź
                        damping: 0.68    // Mniej oscylacji
                        epsilon: 0.3     // Szybsza konwergencja
                        modulus: 0 
                    }
                }
                Behavior on color {
                    ColorAnimation { duration: 70; easing.type: Easing.OutQuad }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
