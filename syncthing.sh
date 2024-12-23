#! /usr/bin/env -S nix shell nixpkgs#bash nixpkgs#coreutils nixpkgs#openssl nixpkgs#age nixpkgs#gnused nixpkgs#unixtools.xxd --command bash

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <hostname> <ssh-identity-file>"
  exit 1
fi

HOSTNAME="$1"
SSH_KEY="$2"

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
  echo "Error: Identity file '$SSH_KEY' not found"
  exit 1
fi

generate_syncthing_keys() {
  local hostname="$1"

  # Check if files already exist
  if [[ -f "./secrets/agenix/${hostname}-syncthing-key.age" ]] ||
    [[ -f "./secrets/agenix/${hostname}-syncthing-cert.age" ]]; then
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
    --output "./secrets/agenix/${hostname}-syncthing-key.age" \
    "$key_path"

  age --encrypt --identity "$SSH_KEY" \
    --output "./secrets/agenix/${hostname}-syncthing-cert.age" \
    "$cert_path"

  # Print device ID for reference
  echo "Syncthing device ID (you'll need this):"
  openssl x509 -in "$cert_path" -text |
    grep -A1 "Subject Key Identifier" |
    tail -n1 |
    tr -d ' ' |
    xxd -r -p |
    base32 |
    tr '[:upper:]' '[:lower:]' |
    sed 's/=//g'

  # Clean up
  rm -rf "$temp_dir"
}

# Add entries to secrets.nix if they don't already exist
echo "Checking/adding entries to secrets.nix..."
for type in "key" "cert"; do
  entry="\"${HOSTNAME}-syncthing-${type}.age\".publicKeys = users ++ [${HOSTNAME}];"
  if ! grep -q "\"${HOSTNAME}-syncthing-${type}\.age\"" ./secrets/agenix/secrets.nix; then
    sed -i "/^}$/i \  $entry" ./secrets/agenix/secrets.nix
  else
    echo "Entry for ${HOSTNAME}-syncthing-${type} already exists in secrets.nix"
  fi
done

generate_syncthing_keys "$HOSTNAME"

echo "Done! Syncthing keys are encrypted."
echo "  - ./secrets/agenix/${HOSTNAME}-syncthing-key.age"
echo "  - ./secrets/agenix/${HOSTNAME}-syncthing-cert.age"
