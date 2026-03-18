#!/usr/bin/env bash
# Backup atuin data. To restore on a new host:
#   cp atuin-backup/* ~/.local/share/atuin/
#   systemctl --user restart atuin-daemon

set -euo pipefail

BACKUP_DIR="${1:-$HOME/atuin-backup}"
ATUIN_DIR="$HOME/.local/share/atuin"

mkdir -p "$BACKUP_DIR"
echo "Backing up to $BACKUP_DIR ..."

for f in key session history.db records.db host_id; do
  if [ -e "$ATUIN_DIR/$f" ]; then
    cp "$ATUIN_DIR/$f" "$BACKUP_DIR/$f"
    echo "  $f: OK ($(wc -c < "$ATUIN_DIR/$f") bytes)"
  else
    echo "  $f: not found, skipping"
  fi
done

echo ""
echo "Done. To restore on a new host:"
echo "  cp $BACKUP_DIR/* ~/.local/share/atuin/"
echo "  systemctl --user restart atuin-daemon"
