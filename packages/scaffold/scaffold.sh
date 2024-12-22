#!/usr/bin/env bash

set -euo pipefail

# Constants
DEFAULT_ARCH="x86_64-linux"
DEFAULT_USERNAME="simonwjackson"
STATE_VERSION="24.11"
BASE_DIR="$(git rev-parse --show-toplevel)"
SSH_KEY=""
SECRETS_FILE="${BASE_DIR}/secrets/agenix/secrets.nix"

# Usage function
show_usage() {
  echo "Usage: scaffold [username@]<system-name> [--arch <architecture>] [--identity <ssh-key-path>]"
  echo "Default architecture: $DEFAULT_ARCH"
  echo "Default username: $DEFAULT_USERNAME"
  exit 1
}

# Add this function after the show_usage function
check_ssh_key() {
  local default_key="$HOME/.ssh/id_rsa"

  if [ -z "$SSH_KEY" ]; then
    if [ -f "$default_key" ]; then
      SSH_KEY="$default_key"
      echo "Using default SSH key: $SSH_KEY"
    else
      echo "Error: No SSH key specified and default key ($default_key) not found"
      echo "Please provide an SSH key using --identity or create a default key"
      exit 1
    fi
  fi

  if [ ! -f "$SSH_KEY" ]; then
    echo "Error: Identity file '$SSH_KEY' not found"
    exit 1
  fi
}

# Create directory and file with content
create_config() {
  local dir="$1"
  local file="$2"
  local content="$3"

  if [ ! -f "$file" ]; then
    echo "Creating $file..."
    mkdir -p "$dir"
    echo "$content" >"$file"
  else
    echo "File already exists: $file"
  fi
}

# Parse username and system name
parse_system_arg() {
  local arg="$1"
  local username_var="$2"
  local system_var="$3"

  if [[ "$arg" == *"@"* ]]; then
    printf -v "$username_var" "%s" "${arg%%@*}"
    printf -v "$system_var" "%s" "${arg#*@}"
  else
    printf -v "$username_var" "%s" "$DEFAULT_USERNAME"
    printf -v "$system_var" "%s" "$arg"
  fi
}

# Validate arguments
if [ $# -lt 1 ]; then
  show_usage
fi

USERNAME=""
SYSTEM_NAME=""
parse_system_arg "$1" USERNAME SYSTEM_NAME
ARCH="$DEFAULT_ARCH"

# Parse optional arguments
shift
while [[ $# -gt 0 ]]; do
  case $1 in
  --arch)
    ARCH="$2"
    shift 2
    ;;
  --identity)
    SSH_KEY="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1"
    exit 1
    ;;
  esac
done

# Replace the existing SSH key validation block with a call to check_ssh_key
check_ssh_key

# System configuration template
SYSTEM_CONFIG=$(
  cat <<EOF
{
  modulesPath,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.mountainous) enabled disabled;
in {
  imports = [

  ];

  mountainous = {
    boot = enabled;
    gaming = {
      core = disabled;
      steam = disabled;
    };
    impermanence = enabled;
    # networking.core.names = [
    #   {
    #     name = "wifi";
    #     mac = "00:00:00:00:00:00";
    #   }
    # ];
    profiles = {
      laptop = disabled;
      workstation = enabled;
    };
    # TODO: encrypt generated syncthing keys
    syncthing = {
      # key = config.age.secrets.$SYSTEM_NAME-syncthing-key.path;
      # cert = config.age.secrets.$SYSTEM_NAME-syncthing-cert.path;
    };
  };

  system.stateVersion = "$STATE_VERSION";
}
EOF
)

# Home configuration template
HOME_CONFIG=$(
  cat <<'EOF'
{ config, lib, pkgs, ... }:

{
  imports = [

  ];

  home = {
    homeDirectory = "/home/\${config.home.username}";
    stateVersion = "$STATE_VERSION"; # WARN: Changing this might break things. Just leave it.
  };
}
EOF
)

# Syncthing configuration template
SYNCTHING_CONFIG=$(
  cat <<EOF
{
  config,
  host,
  ...
}: {
  device = {
    # TODO: Add your syncthing device id here
    id = "0000000-0000000-0000000-0000000-0000000-0000000-0000000-0000000";
    name = "(\${host})";
  };
  shares = {
    # TODO: Add your syncthing shares here
    #  shareName= {
    #   path = "/path/to/share";
    #   type = "sendreceive";
    # };
  };
}
EOF
)

update_secrets_nix() {
  local hostname="$1"

  # Check if secrets.nix exists
  if [ ! -f "${SECRETS_FILE}" ]; then
    echo "Error: ${SECRETS_FILE} not found"
    exit 1
  fi

  echo "Checking secrets.nix configuration..."

  # Only add the host definition if it doesn't already exist
  if ! grep -q "^[[:space:]]*${hostname}[[:space:]]*=" "${SECRETS_FILE}"; then
    echo "Adding host definition for ${hostname}..."
    sed -i "/^let/a\\  ${hostname} = builtins.readFile ../keys/hosts/x86_64-linux_${hostname}_ssh_host_rsa_key.pub;" "${SECRETS_FILE}"
  else
    echo "Host definition for ${hostname} already exists"
  fi

  # Only add to systems list if not already present
  if ! grep -q "^[[:space:]]*${hostname}[[:space:]]*$" "${SECRETS_FILE}"; then
    echo "Adding ${hostname} to systems list..."
    sed -i "/systems = \[/a\\    ${hostname}" "${SECRETS_FILE}"
  else
    echo "System ${hostname} already in systems list"
  fi
}

generate_host_keys() {
  local hostname="$1"
  local host_key_enc="${BASE_DIR}/secrets/keys/hosts/x86_64-linux_${hostname}_ssh_host_rsa_key.age"

  echo "checking host keys for $hostname..."
  if [ ! -f "$host_key_enc" ]; then
    echo "generating new host keys for $hostname..."

    # create temporary directory
    temp_dir=$(mktemp -d)
    temp_key="${temp_dir}/ssh_host_key"

    # Simplified ssh-keygen command
    ssh-keygen -t rsa -f "$temp_key" -N ""

    # encrypt the private key with age and save to the target path
    age --encrypt --identity "$SSH_KEY" --output "$host_key_enc" "$temp_key"

    # copy the public key to the expected location
    cp "${temp_key}.pub" "${host_key_enc%.age}.pub"

    # clean up temporary directory and all its contents
    rm -rf "$temp_dir"

    # Call update_secrets_nix function
    update_secrets_nix "$hostname"

    # Rekey the agenix directory after generating new host keys
    echo "Rekeying agenix secrets..."
    cd "${BASE_DIR}/secrets/agenix" && agenix --rekey
  fi
}

# Create system configuration
create_config \
  "$BASE_DIR/systems/$ARCH/$SYSTEM_NAME" \
  "$BASE_DIR/systems/$ARCH/$SYSTEM_NAME/default.nix" \
  "$SYSTEM_CONFIG"

# Create home configuration
create_config \
  "$BASE_DIR/homes/$ARCH/$USERNAME@$SYSTEM_NAME" \
  "$BASE_DIR/homes/$ARCH/$USERNAME@$SYSTEM_NAME/default.nix" \
  "$HOME_CONFIG"

# Create syncthing configuration
create_config \
  "$BASE_DIR/systems/$ARCH/$SYSTEM_NAME" \
  "$BASE_DIR/systems/$ARCH/$SYSTEM_NAME/syncthing.nix" \
  "$SYNCTHING_CONFIG"

# Add SSH host key generation before the final echo statements
generate_host_keys "$SYSTEM_NAME"

echo "Successfully scaffolded system and home for $USERNAME@$SYSTEM_NAME with architecture $ARCH"
echo
echo "TODOs:"
echo "1. Add your syncthing device ID in systems/$ARCH/$SYSTEM_NAME/syncthing.nix"
echo "2. Configure your syncthing shares in systems/$ARCH/$SYSTEM_NAME/syncthing.nix"
echo "3. Configure syncthing keys in systems/$ARCH/$SYSTEM_NAME/default.nix"
