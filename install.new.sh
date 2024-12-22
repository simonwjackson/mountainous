#!/usr/bin/env -S /run/current-system/sw/bin/nix shell nixpkgs#bash nixpkgs#coreutils nixpkgs#openssh nixpkgs#gum -c bash

set -euo pipefail

# Constants
readonly DEFAULT_SSH_KEY="$HOME/.ssh/id_rsa"
readonly SECRETS_FILE="secrets/agenix/secrets.nix"
readonly USER_HOME="/tundra/permafrost/home/simonwjackson"
readonly IGLOO_MOUNT="/tundra/igloo"

# Helper functions
log_info() { gum log --level info "$1"; }
log_warn() { gum log --level warn "$1"; }
log_error() { gum log --level error "$1"; }

ssh_cmd() {
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@"
}

# Main functions
check_arguments() {
  if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <hostname> <user@ip> <ssh_key_path>"
    echo "Example  $0 cho nixos@192.168.1.247 ~/.ssh/my_key"
    exit 1
  fi
}

setup_variables() {
  HOSTNAME="$1"
  TARGET="$2"
  SSH_KEY="${3:-$DEFAULT_SSH_KEY}"
  USERNAME=$(echo "$TARGET" | cut -d'@' -f1)
  IP=$(echo "$TARGET" | cut -d'@' -f2)
  temp=$(mktemp -d)

  trap 'rm -rf "$temp"' EXIT
}

generate_host_keys() {
  local host_key_path="$temp/etc/ssh/ssh_host_rsa_key"
  local public_key_path="./secrets/keys/hosts/x86_64-linux_${HOSTNAME}_ssh_host_rsa_key.pub"

  log_info "Checking host keys for $HOSTNAME..."

  # Create the directory structure
  install -d -m755 "$temp/etc/ssh"
  install -d -m755 "secrets/keys/hosts"

  # Generate the key pair in the temp directory
  log_info "Generating new host keys for $HOSTNAME..."
  ssh-keygen -t rsa -N "" -f "$host_key_path"

  # Copy the public key to the secrets directory
  cp "${host_key_path}.pub" "$public_key_path"
}

update_secrets_file() {
  log_info "Checking secrets.nix for existing host..."
  if ! grep -q "^\s*${HOSTNAME}\s*=" "$SECRETS_FILE"; then
    log_info "Adding $HOSTNAME to secrets.nix..."
    sed -i "/let/a\  ${HOSTNAME} = builtins.readFile ..\/keys\/hosts\/x86_64-linux_${HOSTNAME}_ssh_host_rsa_key.pub;" "$SECRETS_FILE"

    if ! grep -q "^\s*${HOSTNAME}\s*$" "$SECRETS_FILE"; then
      sed -i "/systems = \[/a\    ${HOSTNAME}" "$SECRETS_FILE"
    fi
  else
    log_warn "Host $HOSTNAME already exists in secrets.nix, skipping update..."
  fi
}

setup_temp_directories() {
  install -d -m700 "$temp/$USER_HOME/.ssh"
  install -d -m700 "$temp/tundra/igloo"

  if [ ! -f "$SSH_KEY" ]; then
    log_error "SSH key not found at: $SSH_KEY"
    exit 1
  fi

  cp "$SSH_KEY" "$temp/$USER_HOME/.ssh/id_rsa"
  chmod 600 "$temp/$USER_HOME/.ssh/id_rsa"

  cp "$SSH_KEY" "$temp/tundra/igloo/id_rsa"
  chmod 600 "$temp/tundra/igloo/id_rsa"
}

update_secrets() {
  log_info "Updating secrets..."
  if ! just up secrets; then
    log_error "Failed to update secrets"
    exit 1
  fi
}

setup_ssh_keys() {
  ssh_cmd "$TARGET" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat > ~/.ssh/authorized_keys" \
    < <(ssh-keygen -y -f "$SSH_KEY")

  ssh_cmd "$TARGET" "chmod 600 ~/.ssh/authorized_keys"
}

finalize_setup() {
  log_info "Setting correct ownership of directories & rebooting..."
  ssh_cmd "$TARGET" "sudo chown -R 1000:100 /mnt/$USER_HOME /mnt/$IGLOO_MOUNT && sudo reboot"
}

deploy_nixos() {
  log_info "Deploying NixOS configuration..."
  nix run github:simonwjackson/nixos-anywhere -- \
    --flake ".#$HOSTNAME" \
    --extra-files "$temp" \
    --phases kexec,disko,install \
    --target-host "$TARGET"
}

main() {
  check_arguments "$@"
  setup_variables "$@"
  generate_host_keys
  update_secrets_file
  setup_temp_directories
  # update_secrets
  setup_ssh_keys
  deploy_nixos
  finalize_setup
}

main "$@"
