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

# Decrypt and place host SSH key
HOST_KEY_ENC="secrets/keys/hosts/x86_64-linux_${HOSTNAME}_ssh_host_rsa_key.age"
if [ -f "$HOST_KEY_ENC" ]; then
  echo "Decrypting host SSH key..."
  age --decrypt --identity "$SSH_KEY" "$HOST_KEY_ENC" > "$temp/etc/ssh/ssh_host_rsa_key"
  chmod 600 "$temp/etc/ssh/ssh_host_rsa_key"
  cp "${HOST_KEY_ENC%.age}.pub" "$temp/etc/ssh/ssh_host_rsa_key.pub"
  chmod 644 "$temp/etc/ssh/ssh_host_rsa_key.pub"
else
  echo "Error: Host SSH key not found at $HOST_KEY_ENC"
  exit 1
fi

# Copy SSH keys
cp "$SSH_KEY" "$temp/tundra/igloo/"
cp "$SSH_KEY" "$temp/$USER_HOME/.ssh/"

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
