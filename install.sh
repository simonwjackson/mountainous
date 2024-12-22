#!/usr/bin/env -S /run/current-system/sw/bin/nix shell nixpkgs#bash nixpkgs#coreutils nixpkgs#openssh -c bash

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <hostname> <user@ip> [ssh_key_path] [nixos-anywhere args...]"
  echo "Example: $0 cho nixos@192.168.1.247 ~/.ssh/my_key"
  exit 1
fi

HOSTNAME="$1"
TARGET="$2"
SSH_KEY="${3:-$HOME/.ssh/id_rsa}"

# Add new section to check and generate host keys
echo "Checking host keys for $HOSTNAME..."
HOST_KEY_PATH="secrets/keys/hosts/x86_64-linux_${HOSTNAME}_ssh_host_rsa_key"
if [ ! -f "$HOST_KEY_PATH" ]; then
  echo "Generating new host keys for $HOSTNAME..."
  ssh-keygen -t rsa -N "" -f "$HOST_KEY_PATH"

  # Update secrets.nix
  echo "Updating secrets.nix..."
  SECRETS_FILE="secrets/agenix/secrets.nix"

  # Add host variable declaration
  sed -i "/let/a\  ${HOSTNAME} = builtins.readFile ..\/keys\/hosts\/x86_64-linux_${HOSTNAME}_ssh_host_rsa_key.pub;" "$SECRETS_FILE"

  # Add to systems list
  sed -i "/systems = \[/a\    ${HOSTNAME}" "$SECRETS_FILE"
fi

#SERNAME=$(echo "$TARGET" | cut -d'@' -f1)
IP=$(echo "$TARGET" | cut -d'@' -f2)

# Create a temporary directory for our extra files
temp=$(mktemp -d)

# Cleanup function
cleanup() {
  rm -rf "$temp"
}
trap cleanup EXIT

# Create the SSH directory structure in our temp folder
USER_HOME="/tundra/permafrost/home/simonwjackson"
IGLOO_MOUNT="/tundra/igloo"
install -d -m700 "$temp/$USER_HOME/.ssh"
install -d -m700 "$temp/tundra/igloo"
install -d -m755 "$temp/etc/ssh"

# Generate host keys locally
cp "$SSH_KEY" "$temp/tundra/igloo/"
cp "$SSH_KEY" "$temp/$USER_HOME/.ssh/"

ls -laR "${temp}"

# echo "Updating secrets..."
# if ! just up secrets; then
#   echo "Error: Failed to update secrets"
#   exit 1
# fi

# Copy authorized keys and set permissions
ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "$TARGET" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat > ~/.ssh/authorized_keys" \
  < <(ssh-keygen -y -f "$SSH_KEY")

ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "$TARGET" "chmod 600 ~/.ssh/authorized_keys"

# Deploy NixOS configuration
echo "Deploying NixOS configuration..."
nix run github:simonwjackson/nixos-anywhere -- \
  --flake ".#$HOSTNAME" \
  --extra-files "$temp" \
  --phases kexec,disko,install \
  --target-host "$TARGET"

# Set correct ownership of directories
echo "Setting correct ownership of directories..."
ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "$TARGET" "sudo chown -R 1000:100 /mnt/$USER_HOME /mnt/$IGLOO_MOUNT && sudo reboot"

echo "Installation complete! The system will reboot automatically."
