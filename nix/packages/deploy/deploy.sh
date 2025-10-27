#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <hostname> <user@ip> [ssh_key_path] [nixos-anywhere args...]"
  echo "Example: $0 cho nixos@192.168.1.247 ~/.ssh/my_key"
  exit 1
fi

HOSTNAME="$1"
TARGET="$2"
SSH_KEY="${3:-$HOME/.ssh/id_rsa}"

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

# Function to generate and encrypt SSH host key
generate_host_key() {
  local hostname="$1"
  local ssh_key="$2"
  local host_key_enc="$3"
  local host_key_pub="${host_key_enc%.age}.pub"

  echo "🔑 Generating new SSH host key for $hostname..."

  # Create temp directory for key generation
  local temp_key_dir
  temp_key_dir=$(mktemp -d)
  trap 'rm -rf "$temp_key_dir"' RETURN

  # Generate SSH host key (4096-bit RSA, no passphrase)
  ssh-keygen -t rsa -b 4096 -N "" -C "host-key-$hostname" \
    -f "$temp_key_dir/ssh_host_rsa_key" >/dev/null 2>&1

  # Encrypt private key with age using user's SSH public key
  age --encrypt --recipient "$(cat "${ssh_key}.pub")" \
    < "$temp_key_dir/ssh_host_rsa_key" \
    > "$host_key_enc"

  # Copy public key
  cp "$temp_key_dir/ssh_host_rsa_key.pub" "$host_key_pub"

  # Stage keys in git for manual review
  git add "$host_key_enc" "$host_key_pub" 2>/dev/null || true

  echo "✅ Generated and encrypted host SSH key"
  echo "📝 Keys staged in git - review and commit before deploying to production"
}

# Decrypt and place host SSH key (generate if doesn't exist)
HOST_KEY_ENC="secrets/keys/hosts/x86_64-linux_${HOSTNAME}_ssh_host_rsa_key.age"
if [ -f "$HOST_KEY_ENC" ]; then
  echo "🔓 Using existing host SSH key..."
else
  echo "⚠️  Host SSH key not found - generating new key..."
  generate_host_key "$HOSTNAME" "$SSH_KEY" "$HOST_KEY_ENC"
fi

echo "🔓 Decrypting host SSH key..."
age --decrypt --identity "$SSH_KEY" "$HOST_KEY_ENC" >"$temp/etc/ssh/ssh_host_rsa_key"
chmod 600 "$temp/etc/ssh/ssh_host_rsa_key"
cp "${HOST_KEY_ENC%.age}.pub" "$temp/etc/ssh/ssh_host_rsa_key.pub"
chmod 644 "$temp/etc/ssh/ssh_host_rsa_key.pub"

# Check for manual-disko.sh script
MANUAL_DISKO_SCRIPT="nix/systems/x86_64-linux/${HOSTNAME}/manual-disko.sh"
USE_MANUAL_DISKO=false
if [ -f "$MANUAL_DISKO_SCRIPT" ]; then
  echo "Found manual-disko.sh for $HOSTNAME - will use manual formatting"
  USE_MANUAL_DISKO=true
fi

# Copy SSH keys
cp "$SSH_KEY" "$temp/tundra/igloo/"
cp "$SSH_KEY" "$temp/$USER_HOME/.ssh/"

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

# Handle manual disk formatting if needed
if [ "$USE_MANUAL_DISKO" = true ]; then
  echo "Transferring manual-disko.sh to target..."
  scp \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$MANUAL_DISKO_SCRIPT" \
    "$TARGET:/tmp/manual-disko.sh"

  echo "Running manual disk formatting on target..."
  ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$TARGET" "chmod +x /tmp/manual-disko.sh && sudo /tmp/manual-disko.sh"

  echo "Manual formatting complete"
fi

# Deploy NixOS configuration
echo "Deploying NixOS configuration..."

# Set phases based on whether manual formatting was done
if [ "$USE_MANUAL_DISKO" = true ]; then
  NIXOS_PHASES="kexec,install"
  echo "Using phases: kexec,install (skipping disko - manual formatting already done)"
else
  NIXOS_PHASES="kexec,disko,install"
  echo "Using phases: kexec,disko,install"
fi

nixos-anywhere \
  --flake ".#$HOSTNAME" \
  --extra-files "$temp" \
  --phases "$NIXOS_PHASES" \
  --no-substitute-on-destination \
  --target-host "$TARGET"

# Set correct ownership of directories
echo "Setting correct ownership of directories..."
ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -t "$TARGET" "sudo mkdir -p /mnt/$USER_HOME /mnt/$IGLOO_MOUNT /mnt/nix/var/nix/profiles/per-user/simonwjackson && sudo chown -R 1000:100 /mnt/$USER_HOME /mnt/$IGLOO_MOUNT /mnt/nix/var/nix/profiles/per-user/simonwjackson && sudo reboot"

echo "Installation complete! The system will reboot automatically."
