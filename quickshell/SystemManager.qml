// ~/.config/quickshell/SystemManager.qml
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    // Pobierz głośność przy starcie i co 2s
    property Process volGet: Process {
        command: ["sh", "-c", "pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\\d+(?=%)' | head -1"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var v = parseInt(data.trim())
                if (!isNaN(v)) GlobalState.volume = v
            }
        }
    }

    property Process brightGet: Process {
        command: ["sh", "-c", "brightnessctl g"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var v = parseInt(data.trim())
                if (!isNaN(v)) GlobalState.brightness = Math.round((v / 255.0) * 100)
            }
        }
    }

    property Timer refreshTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            volGet.running = false
            volGet.running = true
            brightGet.running = false
            brightGet.running = true
        }
    }

    // Procesy do akcji — reuse przez restart
    property Process _volSet: Process {
        property int target: 50
        command: ["pactl", "set-sink-volume", "@DEFAULT_SINK@", target + "%"]
    }

    property Process _brightSet: Process {
        property int target: 80
        command: ["brightnessctl", "s", target + "%"]
    }

    property Process _nightOn: Process {
        command: ["hyprshade", "on", "blue-light-filter"]
    }

    property Process _nightOff: Process {
        command: ["hyprshade", "off"]
    }

    property Process _poweroff: Process {
        command: ["systemctl", "poweroff"]
    }

    property Process _reboot: Process {
        command: ["systemctl", "reboot"]
    }

    property Process _suspend: Process {
        command: ["systemctl", "suspend"]
    }

    function setVolume(val) {
        _volSet.target = Math.round(val)
        _volSet.running = false
        _volSet.running = true
    }

    function setBrightness(val) {
        _brightSet.target = Math.round(val)
        _brightSet.running = false
        _brightSet.running = true
    }

    function toggleNightLight(active) {
        if (active) {
            _nightOn.running = false
            _nightOn.running = true
        } else {
            _nightOff.running = false
            _nightOff.running = true
        }
    }

    function poweroff() {
        _poweroff.running = false
        _poweroff.running = true
    }

    function reboot() {
        _reboot.running = false
        _reboot.running = true
    }

    function suspend() {
        _suspend.running = false
        _suspend.running = true
    }
}
