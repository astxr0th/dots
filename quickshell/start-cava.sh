#!/bin/bash
# Quickshell Cava Setup Script

# Create directory if it doesn't exist
mkdir -p /tmp/qs-cava

# Kill existing cava instances
pkill -f "cava.*qs-cava" 2>/dev/null

# Create named pipe
rm -f /tmp/qs-cava/cava_output_pipe
mkfifo /tmp/qs-cava/cava_output_pipe

# Start cava in background with custom config
cava -p /tmp/qs-cava/cava.ini > /tmp/qs-cava/cava_output_pipe 2>/dev/null &

echo "Cava started for quickshell"
