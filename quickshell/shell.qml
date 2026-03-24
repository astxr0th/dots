//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
// ~/.config/quickshell/shell.qml
import Quickshell
import QtQuick

ShellRoot {
    Bar {}
    Launcher {}
    NotificationPopups {}
    MusicPlayer {}
    CavaVisualizer {}
    ControlPanel {}
    WallpaperPicker {}
    ClipboardHistory {}
    OSD {}
    ShaderOverlay {}   // ← tu
}
