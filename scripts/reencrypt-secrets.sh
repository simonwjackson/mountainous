#!/usr/bin/env bash
# Re-encrypt all secrets with the master SSH key
#
# This script decrypts existing secrets (using any available identity)
# and re-encrypts them with the user's SSH public key (master identity).
#
# Usage: ./scripts/reencrypt-secrets.sh

set -uo pipefail
# Note: not using -e because we want to continue on decrypt failures

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Master identity paths (try multiple locations)
MASTER_KEY="${HOME}/.ssh/id_rsa"
MASTER_KEY_ALT="/tundra/igloo/id_rsa"
USER_PUBKEY="$REPO_ROOT/secrets/keys/users/rsa.pub"

# Find the master private key
if [[ -f "$MASTER_KEY" ]]; then
  echo "Using master key: $MASTER_KEY"
elif [[ -f "$MASTER_KEY_ALT" ]]; then
  MASTER_KEY="$MASTER_KEY_ALT"
  echo "Using master key: $MASTER_KEY"
else
  echo "ERROR: No master key found at $MASTER_KEY or $MASTER_KEY_ALT"
  exit 1
fi

if [[ ! -f "$USER_PUBKEY" ]]; then
  echo "ERROR: User public key not found at $USER_PUBKEY"
  exit 1
fi

echo "Re-encrypting secrets with master key..."
echo "Public key: $USER_PUBKEY"
echo ""

# Counters
success=0
skipped=0
failed=0

# Find all .age files in secrets directories (excluding rekeyed and keys)
while IFS= read -r -d '' secret; do
  # Skip files in rekeyed directory
  if [[ "$secret" == *"/rekeyed/"* ]]; then
    continue
  fi

  # Skip key files (these are SSH keys, not secrets)
  if [[ "$secret" == *"/keys/"* ]]; then
    continue
  fi

  echo -n "Processing: $secret ... "

  # Try to decrypt with master key and re-encrypt
  if rage -d -i "$MASTER_KEY" "$secret" 2>/dev/null |
    rage -e -R "$USER_PUBKEY" -o "${secret}.new" 2>/dev/null; then
    mv "${secret}.new" "$secret"
    echo "OK"
    ((success++))
  else
    # Clean up partial file if it exists
    rm -f "${secret}.new"
    echo "SKIP (already encrypted or different key)"
    ((skipped++))
  fi
done < <(find "$REPO_ROOT/secrets" -name "*.age" -type f -print0)

echo ""
echo "Summary:"
echo "  Re-encrypted: $success"
echo "  Skipped: $skipped"
echo "  Failed: $failed"
echo ""
echo "Next steps:"
echo "  1. Run: nix run .#agenix-rekey -- rekey -a"
echo "  2. Run: git add secrets/rekeyed/"
echo "  3. Test with: just switch <hostname>"
