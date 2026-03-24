#!/bin/bash

CAVA_NAMESPACE="quickshell-cava"
CAVA_OUTPUT_PIPE="/tmp/qs-cava/cava_output_pipe"
CAVA_CONFIG_DIR="/tmp/qs-cava"
CAVA_CONFIG_FILE="$CAVA_CONFIG_DIR/cava.ini"

mkdir -p $CAVA_CONFIG_DIR

# Create cava.ini if it doesn't exist or ensure framerate is 100
if [ ! -f "$CAVA_CONFIG_FILE" ]; then
    printf '[general]\nbars=48\nframerate=100\n[input]\nmethod=pulse\nsource=auto\n[output]\nmethod=raw\nraw_target=/dev/stdout\ndata_format=ascii\nascii_max_range=100\nbar_delimiter=59\nframe_delimiter=10\n' > "$CAVA_CONFIG_FILE"
else
    # Ensure framerate is 100
    sed -i 's/framerate=.*/framerate=100/' "$CAVA_CONFIG_FILE"
fi

# Create named pipe if it doesn't exist
if [ ! -p "$CAVA_OUTPUT_PIPE" ]; then
    mkfifo "$CAVA_OUTPUT_PIPE"
fi

function start_cava() {
    if ! pgrep -x "cava" > /dev/null; then
        # Start cava and redirect its output to the named pipe
        cava -p "$CAVA_CONFIG_FILE" > "$CAVA_OUTPUT_PIPE" &
        echo "CAVA process started."
    fi
}

function stop_cava() {
    if pgrep -x "cava" > /dev/null; then
        killall cava
        echo "CAVA process stopped."
    fi
}

function check_and_toggle_cava() {
    local active_workspace_id=$(hyprctl activeworkspace -j | jq -r ".id")

    local windows_on_workspace=$(hyprctl clients -j | jq --argjson ws_id "$active_workspace_id" \
        '[.[] | select(.workspace.id == $ws_id and .class != "")] | length')

    if [ "$windows_on_workspace" -eq 0 ]; then
        # Brak okien na aktywnym workspace, uruchom CAVA i uczyń widoczną przez IPC
        start_cava
        quickshell ipc cava show
    else
        # Są okna, zatrzymaj CAVA i ukryj przez IPC
        stop_cava
        quickshell ipc cava hide
    fi
}

# Initial check
check_and_toggle_cava

# Listen for Hyprland events
HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t /tmp/hypr/ | head -n 1)}
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    echo "Nie można znaleźć instancji Hyprland."
    exit 1
fi

socat -U - UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do
    if [[ $line == "openwindow"* || $line == "closewindow"* || $line == "movewindow"* || $line == "workspace"* || $line == "activewindow"* ]]; then
        check_and_toggle_cava
    fi
done

# Clean up pipe on exit
trap "rm -f $CAVA_OUTPUT_PIPE" EXIT
