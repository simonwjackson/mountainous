#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: syncthing-keygen <hostname>"
    echo ""
    echo "Generates syncthing identity for a host:"
    echo "  - Writes device ID to hosts/<hostname>/syncthing-device-id"
    echo "  - Outputs key.pem and cert.pem for agenix encryption"
    echo ""
    echo "Example:"
    echo "  syncthing-keygen myhost"
    exit 1
fi

HOSTNAME="$1"

# Find git repository root
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

HOST_DIR="$GIT_ROOT/hosts/$HOSTNAME"
DEVICE_DIR="$GIT_ROOT/devices/$HOSTNAME"

# Determine where to write the device ID
if [ -d "$HOST_DIR" ]; then
    TARGET_DIR="$HOST_DIR"
elif [ -d "$DEVICE_DIR" ]; then
    TARGET_DIR="$DEVICE_DIR"
else
    echo "Error: Neither hosts/$HOSTNAME/ nor devices/$HOSTNAME/ exists"
    echo ""
    echo "For NixOS hosts, create hosts/$HOSTNAME/ first."
    echo "For external devices (phones, etc.), create devices/$HOSTNAME/"
    exit 1
fi

# Create temporary directory for syncthing config
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Generating syncthing identity for: $HOSTNAME"
echo ""

# Generate syncthing certificate and key
syncthing generate --home "$TEMP_DIR"

# Extract device ID from config.xml
if [ ! -f "$TEMP_DIR/config.xml" ]; then
    echo "Error: config.xml not generated"
    exit 1
fi

DEVICE_ID=$(grep -oP '<device id="\K[^"]+' "$TEMP_DIR/config.xml" | head -n 1)

if [ -z "$DEVICE_ID" ]; then
    echo "Error: Could not extract device ID from config.xml"
    exit 1
fi

# Write device ID file
echo "$DEVICE_ID" > "$TARGET_DIR/syncthing-device-id"
git -C "$GIT_ROOT" add "$TARGET_DIR/syncthing-device-id"

# Copy key and cert for agenix encryption
cp "$TEMP_DIR/key.pem" "./$HOSTNAME-syncthing-key.pem"
cp "$TEMP_DIR/cert.pem" "./$HOSTNAME-syncthing-cert.pem"

echo "Done!"
echo ""
echo "Device ID written to: ${TARGET_DIR#$GIT_ROOT/}/syncthing-device-id"
echo "Device ID: $DEVICE_ID"
echo ""
echo "Key and cert saved to:"
echo "  ./$HOSTNAME-syncthing-key.pem"
echo "  ./$HOSTNAME-syncthing-cert.pem"
echo ""
echo "Next: encrypt with agenix and enable syncthing:"
echo ""
echo "  # In your host config:"
echo "  mountainous.features.syncthing.enable = true;"
