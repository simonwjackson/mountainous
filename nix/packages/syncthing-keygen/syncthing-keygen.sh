#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: syncthing-keygen <hostname>"
    echo ""
    echo "Generates syncthing identity (key.pem and cert.pem) for a host"
    echo ""
    echo "Example:"
    echo "  syncthing-keygen myhost"
    exit 1
fi

HOSTNAME="$1"

# Find git repository root
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
SECRETS_DIR="$GIT_ROOT/secrets/agenix"

if [ ! -d "$SECRETS_DIR" ]; then
    echo "Warning: Secrets directory not found: $SECRETS_DIR"
    echo "Files will be saved to current directory"
    SECRETS_DIR="."
fi

# Create temporary directory for syncthing config
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Generating syncthing identity for: $HOSTNAME"
echo ""

# Generate syncthing certificate and key
cd "$TEMP_DIR"
syncthing generate --home "$TEMP_DIR"

# Extract device ID from config.xml
if [ ! -f "$TEMP_DIR/config.xml" ]; then
    echo "Error: config.xml not generated"
    exit 1
fi

# Extract device ID using grep and sed
DEVICE_ID=$(grep -oP '<device id="\K[^"]+' "$TEMP_DIR/config.xml" | head -n 1)

if [ -z "$DEVICE_ID" ]; then
    echo "Error: Could not extract device ID from config.xml"
    exit 1
fi

# Copy key and cert to output files
cp "$TEMP_DIR/key.pem" "./$HOSTNAME-syncthing-key.pem"
cp "$TEMP_DIR/cert.pem" "./$HOSTNAME-syncthing-cert.pem"

echo "Generated syncthing identity for: $HOSTNAME"
echo "Device ID: $DEVICE_ID"
echo ""
echo "Add to your system config:"
echo "  mountainous.syncthing.deviceId = \"$DEVICE_ID\";"
echo ""
echo "Key and cert saved to:"
echo "  ./$HOSTNAME-syncthing-key.pem"
echo "  ./$HOSTNAME-syncthing-cert.pem"
echo ""
echo "To encrypt with agenix, run:"
echo "  cd $SECRETS_DIR"
echo "  agenix -e $HOSTNAME-syncthing-key.age < $(pwd)/$HOSTNAME-syncthing-key.pem"
echo "  agenix -e $HOSTNAME-syncthing-cert.age < $(pwd)/$HOSTNAME-syncthing-cert.pem"
echo ""
echo "After encrypting, add to secrets.nix:"
echo "  \"$HOSTNAME-syncthing-key.age\".publicKeys = [hosts.$HOSTNAME];"
echo "  \"$HOSTNAME-syncthing-cert.age\".publicKeys = [hosts.$HOSTNAME];"
