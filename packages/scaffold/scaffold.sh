#! /usr/bin/env -S nix shell nixpkgs#bash nixpkgs#coreutils nixpkgs#openssl nixpkgs#age nixpkgs#gnused --command bash

set -euo pipefail

DEFAULT_ARCH="x86_64-linux"
DEFAULT_USERNAME="simonwjackson"
BASE_DIR="$(git rev-parse --show-toplevel)"
SECRETS_FILE="${BASE_DIR}/secrets/default.nix"
SSH_KEY=""
ARCH="$DEFAULT_ARCH"
USER_PUBKEY=""

show_usage() {
  echo "Usage: scaffold [username@]<system-name> [--arch <architecture>] [--identity <ssh-key-path>]"
  echo "Default architecture: $DEFAULT_ARCH"
  echo "Default username: $DEFAULT_USERNAME"
  exit 1
}

check_ssh_key() {
  local default_keys=("$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa")

  if [ -z "$SSH_KEY" ]; then
    for key in "${default_keys[@]}"; do
      if [ -f "$key" ]; then
        SSH_KEY="$key"
        break
      fi
    done
  fi

  if [ -z "$SSH_KEY" ] || [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH key not found. Use --identity to specify one."
    exit 1
  fi

  USER_PUBKEY="${SSH_KEY}.pub"
  if [ ! -f "$USER_PUBKEY" ]; then
    echo "Error: SSH public key '$USER_PUBKEY' not found"
    exit 1
  fi

  echo "Using SSH key: $SSH_KEY"
}

create_config() {
  local dir="$1"
  local file="$2"
  local content="$3"

  if [ ! -f "$file" ]; then
    echo "Creating $file..."
    mkdir -p "$dir"
    printf '%s\n' "$content" >"$file"
    git add "$file"
  elif [[ "$file" == *.nix ]]; then
    echo "Nix configuration file already exists: $file"
  fi
}

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

generate_host_keys() {
  local hostname="$1"
  local host_key_enc="${BASE_DIR}/secrets/keys/hosts/${ARCH}_${hostname}_ssh_host_rsa_key.age"
  local host_key_pub="${host_key_enc%.age}.pub"

  echo "Checking host keys for $hostname..."
  if [ -f "$host_key_enc" ] && [ -f "$host_key_pub" ]; then
    echo "Host keys already exist for $hostname"
    return 0
  fi

  echo "Generating new host keys for $hostname..."

  local temp_dir
  local temp_key
  temp_dir=$(mktemp -d)
  temp_key="${temp_dir}/ssh_host_rsa_key"

  ssh-keygen -t rsa -b 4096 -f "$temp_key" -N "" -C "host-key-${hostname}" >/dev/null

  age --encrypt \
    --recipient "$(cat "$USER_PUBKEY")" \
    --output "$host_key_enc" \
    "$temp_key"
  cp "${temp_key}.pub" "$host_key_pub"

  rm -rf "$temp_dir"
  git add "$host_key_enc" "$host_key_pub"
}

update_secrets_nix() {
  local hostname="$1"
  local host_key_pub="${BASE_DIR}/secrets/keys/hosts/${ARCH}_${hostname}_ssh_host_rsa_key.pub"

  if [ ! -f "$SECRETS_FILE" ]; then
    echo "Error: ${SECRETS_FILE} not found"
    exit 1
  fi

  if [ ! -f "$host_key_pub" ]; then
    echo "Error: Host public key not found: $host_key_pub"
    exit 1
  fi

  echo "Updating ${SECRETS_FILE} for ${hostname}..."

  local pubkey
  pubkey="$(cat "$host_key_pub")"

  # Add host key variable if not already present
  if ! grep -q "^[[:space:]]*${hostname}[[:space:]]*=" "$SECRETS_FILE"; then
    # Insert after the last host key definition, before simonwjackson
    sed -i "/^[[:space:]]*simonwjackson[[:space:]]*=/i\\  ${hostname} = \"${pubkey}\";" "$SECRETS_FILE"
    echo "  Added ${hostname} key variable"
  else
    echo "  ${hostname} key variable already exists"
  fi

  # Add host to allKeys if not already present
  if ! grep -q "allKeys.*${hostname}" "$SECRETS_FILE"; then
    sed -i "s/\(allKeys = \[.*\)\(simonwjackson\]/\1${hostname} \2/" "$SECRETS_FILE"
    echo "  Added ${hostname} to allKeys"
  else
    echo "  ${hostname} already in allKeys"
  fi

  git add "$SECRETS_FILE"
}

generate_syncthing_keys() {
  local hostname="$1"
  local host_pubkey_file="${BASE_DIR}/secrets/keys/hosts/${ARCH}_${hostname}_ssh_host_rsa_key.pub"
  local secret_dir="${BASE_DIR}/secrets/hosts/${hostname}"
  local encrypted_key="${secret_dir}/syncthing-key.age"
  local encrypted_cert="${secret_dir}/syncthing-cert.age"

  mkdir -p "$secret_dir"

  if [ -f "$encrypted_key" ] && [ -f "$encrypted_cert" ]; then
    echo "Syncthing secrets already exist for ${hostname}"
    git add "$secret_dir" 2>/dev/null || true
    return 0
  fi

  local temp_dir
  local key_path
  local cert_path
  temp_dir=$(mktemp -d)
  key_path="${temp_dir}/device.key"
  cert_path="${temp_dir}/cert.pem"

  echo "Generating Syncthing identity for $hostname..."
  openssl ecparam -genkey -name secp521r1 -noout -out "$key_path"
  openssl req -new -x509 -key "$key_path" -out "$cert_path" -days 3650 -subj "/CN=syncthing"

  # Encrypt for all keys (host + user) — secrets/default.nix auto-discovery
  # handles the agenix wiring; we just need the files to exist.
  age --encrypt \
    --recipient "$(cat "$host_pubkey_file")" \
    --recipient "$(cat "$USER_PUBKEY")" \
    --output "$encrypted_key" \
    "$key_path"

  age --encrypt \
    --recipient "$(cat "$host_pubkey_file")" \
    --recipient "$(cat "$USER_PUBKEY")" \
    --output "$encrypted_cert" \
    "$cert_path"

  rm -rf "$temp_dir"
  git add "$encrypted_key" "$encrypted_cert"
}

# ── Argument parsing ─────────────────────────────────────────────────

if [ $# -lt 1 ]; then
  show_usage
fi

USERNAME=""
SYSTEM_NAME=""
parse_system_arg "$1" USERNAME SYSTEM_NAME

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

check_ssh_key

# ── Host config ──────────────────────────────────────────────────────

HOST_CONFIG=$(
  cat <<EOF
{lib, ...}: {
  imports = [
    # ./disko.nix
    # ./hardware.nix
  ];

  networking.hostName = "${SYSTEM_NAME}";
  time.timeZone = "America/Denver";

  nixpkgs.config.allowUnfree = true;

  mountainous = {
    presets.core.enable = true;
    presets.server.enable = true;

    features.device = {
      role = "portable";
      capabilities = {
        battery = false;
        formFactor = "desktop";
        touchscreen = false;
      };
    };
  };

  system.stateVersion = "26.05";
}
EOF
)

create_config \
  "${BASE_DIR}/hosts/${SYSTEM_NAME}" \
  "${BASE_DIR}/hosts/${SYSTEM_NAME}/default.nix" \
  "$HOST_CONFIG"

# ── Secrets & keys ───────────────────────────────────────────────────

generate_host_keys "$SYSTEM_NAME"
update_secrets_nix "$SYSTEM_NAME"
generate_syncthing_keys "$SYSTEM_NAME"

echo ""
echo "✅ Successfully scaffolded host ${SYSTEM_NAME}"
echo ""
echo "Next steps:"
echo "  1. Add ${SYSTEM_NAME} to flake.nix nixosConfigurations:"
echo "       ${SYSTEM_NAME} = mkHost {"
echo "         system = \"${ARCH}\";"
echo "         hostPath = ./hosts/${SYSTEM_NAME};"
echo "       };"
echo "  2. Create hosts/${SYSTEM_NAME}/hardware.nix and hosts/${SYSTEM_NAME}/disko.nix"
echo "  3. Run: just rekey"
echo "  4. Commit and deploy: nix run .#deploy -- ${SYSTEM_NAME} <user@ip>"
