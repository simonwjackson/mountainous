#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <hostname> <user@ip> [ssh_key_path] [target_arch]"
  echo "Example: $0 zao nixos@192.168.1.243 ~/.ssh/my_key x86_64-linux"
  echo ""
  echo "Arguments:"
  echo "  hostname     - NixOS configuration name (e.g., zao, fuji)"
  echo "  user@ip      - Target host SSH address"
  echo "  ssh_key_path - Path to SSH private key (default: ~/.ssh/id_rsa)"
  echo "  target_arch  - Target architecture (default: x86_64-linux)"
  echo ""
  echo "Environment variables:"
  echo "  DEPLOY_PROXY_JUMP  - SSH ProxyJump host (e.g., rakku)"
  echo "  DEPLOY_BUILD_ON    - Where to build: local (default) or remote"
  exit 1
fi

HOSTNAME="$1"
TARGET="$2"
SSH_KEY="${3:-$HOME/.ssh/id_rsa}"
TARGET_ARCH="${4:-x86_64-linux}"
PROXY_JUMP="${DEPLOY_PROXY_JUMP:-}"
BUILD_ON="${DEPLOY_BUILD_ON:-local}"

# SSH options shared across all ssh/scp calls
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
if [ -n "$PROXY_JUMP" ]; then
  SSH_OPTS+=(-o "ProxyJump=$PROXY_JUMP")
fi

# Create a temporary directory for extra files
temp=$(mktemp -d)
cleanup() { rm -rf "$temp"; }
trap cleanup EXIT

# Standard paths for the target filesystem
install -d -m755 "$temp/etc/ssh"
install -d -m700 "$temp/home/simonwjackson/.ssh"

# ── Host SSH key ─────────────────────────────────────────────────────

generate_host_key() {
  local hostname="$1"
  local ssh_key="$2"
  local host_key_enc="$3"
  local host_key_pub="${host_key_enc%.age}.pub"

  echo "🔑 Generating new SSH host key for $hostname..."

  local temp_key_dir
  temp_key_dir=$(mktemp -d)
  trap 'rm -rf "$temp_key_dir"' RETURN

  ssh-keygen -t rsa -b 4096 -N "" -C "host-key-$hostname" \
    -f "$temp_key_dir/ssh_host_rsa_key" >/dev/null 2>&1

  age --encrypt --recipient "$(cat "${ssh_key}.pub")" \
    <"$temp_key_dir/ssh_host_rsa_key" \
    >"$host_key_enc"

  cp "$temp_key_dir/ssh_host_rsa_key.pub" "$host_key_pub"
  git add "$host_key_enc" "$host_key_pub" 2>/dev/null || true

  echo "✅ Generated and encrypted host SSH key"
  echo "📝 Keys staged in git — review and commit before deploying to production"
}

HOST_KEY_ENC="secrets/keys/hosts/${TARGET_ARCH}_${HOSTNAME}_ssh_host_rsa_key.age"
if [ -f "$HOST_KEY_ENC" ]; then
  echo "🔓 Using existing host SSH key..."
else
  echo "⚠️  Host SSH key not found — generating new key..."
  generate_host_key "$HOSTNAME" "$SSH_KEY" "$HOST_KEY_ENC"
fi

echo "🔓 Decrypting host SSH key..."
age --decrypt --identity "$SSH_KEY" "$HOST_KEY_ENC" >"$temp/etc/ssh/ssh_host_rsa_key"
chmod 600 "$temp/etc/ssh/ssh_host_rsa_key"
cp "${HOST_KEY_ENC%.age}.pub" "$temp/etc/ssh/ssh_host_rsa_key.pub"
chmod 644 "$temp/etc/ssh/ssh_host_rsa_key.pub"

# ── User SSH key ─────────────────────────────────────────────────────

cp "$SSH_KEY" "$temp/home/simonwjackson/.ssh/"
chmod 600 "$temp/home/simonwjackson/.ssh/$(basename "$SSH_KEY")"

# Push authorized_keys to the installer so nixos-anywhere can connect
ssh "${SSH_OPTS[@]}" "$TARGET" \
  "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat > ~/.ssh/authorized_keys" \
  < <(ssh-keygen -y -f "$SSH_KEY")
ssh "${SSH_OPTS[@]}" "$TARGET" "chmod 600 ~/.ssh/authorized_keys"

# ── Deploy ───────────────────────────────────────────────────────────

NIXOS_ANYWHERE_ARGS=(
  --flake ".#$HOSTNAME"
  --extra-files "$temp"
  --phases "kexec,disko,install"
  --target-host "$TARGET"
)

if [ "$BUILD_ON" = "remote" ]; then
  NIXOS_ANYWHERE_ARGS+=(--build-on remote)
fi

if [ -n "$PROXY_JUMP" ]; then
  NIXOS_ANYWHERE_ARGS+=(--ssh-option "ProxyJump=$PROXY_JUMP")
fi

NIXOS_ANYWHERE_ARGS+=(--ssh-option StrictHostKeyChecking=no --ssh-option UserKnownHostsFile=/dev/null)

echo "Deploying NixOS configuration..."
nixos-anywhere "${NIXOS_ANYWHERE_ARGS[@]}"

# ── Post-install fixup ───────────────────────────────────────────────

echo "Setting correct ownership..."
ssh "${SSH_OPTS[@]}" -t "$TARGET" \
  "sudo mkdir -p /home/simonwjackson && sudo chown -R 1000:100 /home/simonwjackson && sudo reboot"

echo "Installation complete! The system will reboot automatically."
