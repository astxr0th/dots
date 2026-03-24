// ~/.config/quickshell/GlobalState.qml
pragma Singleton
import Quickshell
import QtQuick

QtObject {
    id: root

    property bool panelOpen:           false
    property bool launcherOpen:        false
    property bool wallpaperPickerOpen: false
    property bool clipboardOpen:       false
    property bool cavaEnabled:         true
    property bool shadersEnabled:      true   // ← nowe
    property real volume:              50
    property real brightness:          80
    property bool nightLight:          false

    property color dynAccent:   "#cba6f7"
    property color dynAccent2:  "#b4befe"
    property color dynBg:       "#11111b"
    property color dynText:     "#cdd6f4"
    property color dynSubtext:  "#a6adc8"
    property color dynSurface:  "#181825"
    property color dynSurface2: "#1e1e2e"
    property color dynBorder:   "#313244"
    property color dynMuted:    "#6c7086"

    function applyWalColors(jsonText) {
        try {
            var data = JSON.parse(jsonText)
            var c = data.colors; var s = data.special
            if (!c || !s) return
            dynBg   = s.background || "#11111b"
            dynText = s.foreground || "#cdd6f4"
            var candidates = [c.color1, c.color2, c.color3, c.color4, c.color5, c.color6]
            var best = candidates[0] || "#cba6f7"; var bestSat = 0
            for (var i = 0; i < candidates.length; i++) {
                var col = candidates[i]; if (!col) continue
                var sat = colorSaturation(col)
                if (sat > bestSat) { bestSat = sat; best = col }
            }
            dynAccent  = best
            var second = candidates.filter(x => x && x !== best)[0] || c.color2 || "#b4befe"
            dynAccent2 = second
            dynSurface  = lightenColor(dynBg, 0.08)
            dynSurface2 = lightenColor(dynBg, 0.16)
            dynBorder   = lightenColor(dynBg, 0.28)
            dynMuted    = lightenColor(dynBg, 0.55)
            dynSubtext  = blendColor(dynText, dynBg, 0.55)
        } catch(e) {}
    }

    function hexToRgb(hex) {
        return { r: parseInt(hex.slice(1,3),16)/255, g: parseInt(hex.slice(3,5),16)/255, b: parseInt(hex.slice(5,7),16)/255 }
    }
    function colorSaturation(hex) {
        var rgb = hexToRgb(hex); var max = Math.max(rgb.r,rgb.g,rgb.b); var min = Math.min(rgb.r,rgb.g,rgb.b)
        var l = (max+min)/2; if (max===min) return 0; var d = max-min
        return l > 0.5 ? d/(2-max-min) : d/(max+min)
    }
    function lightenColor(base, amount) {
        var r=parseInt(String(base).slice(1,3),16), g=parseInt(String(base).slice(3,5),16), b=parseInt(String(base).slice(5,7),16)
        return Qt.rgba(Math.round(r+(255-r)*amount)/255, Math.round(g+(255-g)*amount)/255, Math.round(b+(255-b)*amount)/255, 1)
    }
    function blendColor(a, b, t) {
        var ar=parseInt(String(a).slice(1,3),16), ag=parseInt(String(a).slice(3,5),16), ab=parseInt(String(a).slice(5,7),16)
        var br=parseInt(String(b).slice(1,3),16), bg2=parseInt(String(b).slice(3,5),16), bb=parseInt(String(b).slice(5,7),16)
        return Qt.rgba((ar*t+br*(1-t))/255, (ag*t+bg2*(1-t))/255, (ab*t+bb*(1-t))/255, 1)
    }
}
