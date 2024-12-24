#! /usr/bin/env -S nix shell nixpkgs#bash nixpkgs#coreutils nixpkgs#openssl nixpkgs#age nixpkgs#gnused --command bash

set -euo pipefail

# Constants
DEFAULT_ARCH="x86_64-linux"
DEFAULT_USERNAME="simonwjackson"
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

# Check SSH key
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
    git add "$file"
  elif [[ "$file" == *.nix ]]; then
    echo "Nix configuration file already exists: $file"
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

# Generate and encrypt Syncthing keys
generate_syncthing_keys() {
  local hostname="$1"

  # Get device ID
  local device_id="0000000-0000000-0000000-0000000-0000000-0000000-0000000-0000000"

  echo "Syncthing device ID: $device_id"

  # Create Syncthing config regardless of key existence
  local SYNCTHING_CONFIG
  SYNCTHING_CONFIG=$(
    cat <<EOF
{
  config,
  host,
  ...
}: {
  device = {
    # id = "${device_id}";
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

  # Create syncthing configuration with the correct device ID
  create_config \
    "$BASE_DIR/systems/$ARCH/$hostname" \
    "$BASE_DIR/systems/$ARCH/$hostname/syncthing.nix" \
    "$SYNCTHING_CONFIG"

  # Check if files already exist
  if [[ -f "${BASE_DIR}/secrets/agenix/${hostname}-syncthing-key.age" ]] ||
    [[ -f "${BASE_DIR}/secrets/agenix/${hostname}-syncthing-cert.age" ]]; then
    echo "Syncthing keys already exist for ${hostname}. Skipping generation."
    return 0
  fi

  local temp_dir
  temp_dir=$(mktemp -d)
  local key_path="${temp_dir}/device.key"
  local cert_path="${temp_dir}/cert.pem"
  local combined_path="${temp_dir}/key.pem"

  echo "Generating Syncthing keys for $hostname..."

  # Generate private key (ECDSA with P-521 curve)
  openssl ecparam -genkey -name secp521r1 -noout -out "$key_path"

  # Generate self-signed certificate (valid for 10 years)
  openssl req -new -x509 -key "$key_path" -out "$cert_path" -days 3650 -subj "/CN=syncthing"

  # Combine key and cert
  cat "$key_path" "$cert_path" >"$combined_path"

  # Encrypt the files with age
  age --encrypt --identity "$SSH_KEY" \
    --output "${BASE_DIR}/secrets/agenix/${hostname}-syncthing-key.age" \
    "$key_path"
  git add "${BASE_DIR}/secrets/agenix/${hostname}-syncthing-key.age"

  age --encrypt --identity "$SSH_KEY" \
    --output "${BASE_DIR}/secrets/agenix/${hostname}-syncthing-cert.age" \
    "$cert_path"
  git add "${BASE_DIR}/secrets/agenix/${hostname}-syncthing-cert.age"

  # Clean up
  rm -rf "$temp_dir"
}

# Update secrets.nix for syncthing keys
update_secrets_nix_syncthing() {
  local hostname="$1"

  # Ensure host definition exists first
  update_secrets_nix "$hostname"

  echo "Checking/adding Syncthing entries to secrets.nix..."
  for type in "key" "cert"; do
    local entry="\"${hostname}-syncthing-${type}.age\".publicKeys = users ++ [${hostname}];"
    if ! grep -q "\"${hostname}-syncthing-${type}\.age\"" "$SECRETS_FILE"; then
      sed -i "/^}$/i \  $entry" "$SECRETS_FILE"
    else
      echo "Entry for ${hostname}-syncthing-${type} already exists in secrets.nix"
    fi
  done
}

# Generate and encrypt host keys
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
    git add "$host_key_enc"

    # copy the public key to the expected location
    cp "${temp_key}.pub" "${host_key_enc%.age}.pub"
    git add "${host_key_enc%.age}.pub"

    # clean up temporary directory and all its contents
    rm -rf "$temp_dir"

    # Rekey the agenix directory after generating new host keys
    echo "Rekeying agenix secrets..."
    cd "${BASE_DIR}/secrets/agenix" && agenix --rekey
  fi
}

# Update secrets.nix for host keys
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
    boot = disabled;
    disks = {
      frostbite = {
        enable = true;
        # device = "/dev/disk/by-id/<disk>";
        swapSize = "4G";
      };
    };
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
    base = enabled;
      laptop = disabled;
      workstation = enabled;
    };
  };

  system.stateVersion = "24.11";
}
EOF
)

# Home configuration template
HOME_CONFIG=$(
  cat <<'EOF'
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [];

  mountainous = {
    profiles.base.enable = true;
  };

  home = {
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "24.11"; # WARN: Changing this might break things. Just leave it.
  };
}
EOF
)

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

# Check SSH key
check_ssh_key

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

# Generate and encrypt keys
generate_host_keys "$SYSTEM_NAME"
update_secrets_nix "$SYSTEM_NAME"
generate_syncthing_keys "$SYSTEM_NAME"
update_secrets_nix_syncthing "$SYSTEM_NAME"

echo "Successfully scaffolded system and home for $USERNAME@$SYSTEM_NAME with architecture $ARCH"
