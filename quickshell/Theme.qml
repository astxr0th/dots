// ~/.config/quickshell/Theme.qml
// Font: install Nunito → `yay -S ttf-nunito`
pragma Singleton
import QtQuick

QtObject {
    readonly property color bg:       "#11111b"
    readonly property color surface:  "#181825"
    readonly property color surface2: "#1e1e2e"
    readonly property color surface3: "#313244"
    readonly property color accent:   "#cba6f7"
    readonly property color accent2:  "#b4befe"
    readonly property color accent3:  "#89b4fa"
    readonly property color text:     "#cdd6f4"
    readonly property color subtext:  "#a6adc8"
    readonly property color muted:    "#6c7086"
    readonly property color border:   "#313244"
    readonly property color success:  "#86efac"
    readonly property color warning:  "#fbbf24"
    readonly property color error:    "#f87171"

    // Nunito — warm, rounded, premium UI font
    // Fallback: CaskaydiaCove Nerd Font
    readonly property string fontUI:      "Nunito"
    readonly property string fontDisplay: "Nunito"
    readonly property string fontMono:    "JetBrains Mono"
    readonly property string fontIcons:   "CaskaydiaCove Nerd Font"

    readonly property int radius:   10
    readonly property int radiusSm: 6
    readonly property int spacing:  8
}
