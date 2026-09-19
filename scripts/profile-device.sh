#!/usr/bin/env nix-shell
#! nix-shell -i bash -p openssh coreutils gnutar gzip

set -euo pipefail

TARGET="root@100.84.190.3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKTREE="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_OUT="$WORKTREE/docs/research/target-hardware-profile"

echo "=== 1. Copying collection script to $TARGET ==="
scp -F /dev/null "$SCRIPT_DIR/collect-hardware-profile-target.sh" "$TARGET:/tmp/collect-hardware-profile-target.sh"

echo "=== 2. Running collection on $TARGET ==="
ssh -F /dev/null "$TARGET" "chmod +x /tmp/collect-hardware-profile-target.sh && /tmp/collect-hardware-profile-target.sh"

echo "=== 3. Retrieving profile archive from $TARGET ==="
mkdir -p "$LOCAL_OUT"
scp -F /dev/null "$TARGET:/tmp/target-hardware-profile.tar.gz" "$LOCAL_OUT/target-hardware-profile.tar.gz"

echo "=== 4. Extracting archive locally to $LOCAL_OUT ==="
tar -xzf "$LOCAL_OUT/target-hardware-profile.tar.gz" -C "$LOCAL_OUT" --strip-components=1

echo "=== Profile extraction complete ==="
echo "Summary:"
cat "$LOCAL_OUT/summary.txt" | head -n 40
