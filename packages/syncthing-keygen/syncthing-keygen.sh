#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: syncthing-keygen <hostname>"
    echo ""
    echo "Generates syncthing identity for a host or external device:"
    echo "  - For NixOS hosts: writes/updates hosts/<hostname>/syncthing.nix"
    echo "  - For external devices: writes devices/<hostname>/syncthing-device-id"
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
    TARGET_TYPE="host"
    TARGET_PATH="$HOST_DIR/syncthing.nix"
elif [ -d "$DEVICE_DIR" ]; then
    TARGET_TYPE="device"
    TARGET_PATH="$DEVICE_DIR/syncthing-device-id"
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

if [ "$TARGET_TYPE" = "host" ]; then
    if [ -f "$TARGET_PATH" ]; then
        if grep -qE '^[[:space:]]*deviceId = "[^"]*";' "$TARGET_PATH"; then
            sed -i -E "s|^[[:space:]]*deviceId = \"[^\"]*\";|  deviceId = \"$DEVICE_ID\";|" "$TARGET_PATH"
        else
            TEMP_MANIFEST="$TEMP_DIR/syncthing.nix"
            INSERTED=false

            while IFS= read -r line; do
                printf '%s\n' "$line" >> "$TEMP_MANIFEST"
                if [ "$INSERTED" = false ] && [[ "$line" =~ ^[[:space:]]*\{$ ]]; then
                    printf '  deviceId = "%s";\n\n' "$DEVICE_ID" >> "$TEMP_MANIFEST"
                    INSERTED=true
                fi
            done < "$TARGET_PATH"

            if [ "$INSERTED" = false ]; then
                echo "Error: $TARGET_PATH is not a Nix attrset; expected opening '{'"
                exit 1
            fi

            mv "$TEMP_MANIFEST" "$TARGET_PATH"
        fi
    else
        printf '{\n  deviceId = "%s";\n\n  shares = { };\n}\n' "$DEVICE_ID" > "$TARGET_PATH"
    fi
else
    printf '%s\n' "$DEVICE_ID" > "$TARGET_PATH"
fi

git -C "$GIT_ROOT" add "$TARGET_PATH"

# Copy key and cert for agenix encryption
cp "$TEMP_DIR/key.pem" "./$HOSTNAME-syncthing-key.pem"
cp "$TEMP_DIR/cert.pem" "./$HOSTNAME-syncthing-cert.pem"

echo "Done!"
echo ""
echo "Device ID: $DEVICE_ID"
echo ""

if [ "$TARGET_TYPE" = "host" ]; then
    echo "Host manifest written to: ${TARGET_PATH#$GIT_ROOT/}"
    echo ""
    echo "Syncthing will be auto-enabled for this host when the manifest exists."
else
    echo "Device ID written to: ${TARGET_PATH#$GIT_ROOT/}"
fi

echo ""
echo "Key and cert saved to:"
echo "  ./$HOSTNAME-syncthing-key.pem"
echo "  ./$HOSTNAME-syncthing-cert.pem"
