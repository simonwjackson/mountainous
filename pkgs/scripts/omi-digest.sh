
# Omi Transcript Digest
# Reads new transcripts and marks them for processing by a spawned agent session
# The actual extraction is done by the agent (token-based), this script just tracks state


OMI_DIR="${OMI_DIR:-$HOME/omi}"
TRANSCRIPTS_DIR="$OMI_DIR/transcripts"
DIGEST_STATE="$OMI_DIR/.digest-state.json"

# Initialize state if missing
if [[ ! -f "$DIGEST_STATE" ]]; then
  echo '{"processed": []}' > "$DIGEST_STATE"
fi

# Get list of already-processed files
PROCESSED="$(jq -r '.processed[]' "$DIGEST_STATE")"

# Find unprocessed transcripts
UNPROCESSED=()
for f in "$TRANSCRIPTS_DIR"/*.md; do
  [[ -f "$f" ]] || continue
  BASENAME="$(basename "$f")"
  if ! echo "$PROCESSED" | grep -qxF "$BASENAME"; then
    UNPROCESSED+=("$BASENAME")
  fi
done

echo "${#UNPROCESSED[@]}"

# Output the list (one per line)
for f in "${UNPROCESSED[@]}"; do
  echo "$f"
done
