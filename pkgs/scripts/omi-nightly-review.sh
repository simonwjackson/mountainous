#!/usr/bin/env bash
# Omi Nightly Classification Review
# Shows the day's transcripts grouped by classification with Simon's key quotes
# so we can spot misclassifications and refine the Groq prompt.


OMI_DIR="${OMI_DIR:-$HOME/omi}"
STATE_FILE="$OMI_DIR/.pipeline-state.json"
TRANSCRIPTS_DIR="$OMI_DIR/transcripts"

# Default to today, accept date arg
DATE="${1:-$(date -u +%Y-%m-%d)}"

echo "=== Omi Nightly Review: $DATE ==="
echo ""

# Get all transcripts for this date
FILES=$(ls "$TRANSCRIPTS_DIR/${DATE}"*.md 2>/dev/null || true)
if [[ -z "$FILES" ]]; then
  echo "No transcripts for $DATE"
  exit 0
fi

# For each classification bucket, show transcripts
for CLASS in actionable mundane media media-auto noise skipped; do
  MATCHES=()
  while IFS= read -r file; do
    BASENAME="$(basename "$file")"
    FILE_CLASS="$(jq -r --arg f "$BASENAME" \
      '.conversations[] | select(.file == $f) | .classification // "unknown"' \
      "$STATE_FILE" 2>/dev/null || echo "unknown")"
    
    if [[ "$FILE_CLASS" == "$CLASS" ]]; then
      MATCHES+=("$file")
    fi
  done <<< "$FILES"

  [[ ${#MATCHES[@]} -eq 0 ]] && continue

  echo "### $CLASS (${#MATCHES[@]})"
  echo ""
  
  for file in "${MATCHES[@]}"; do
    TITLE="$(grep '^title:' "$file" | head -1 | sed 's/title: //; s/"//g')"
    # Extract just User's lines (Simon), truncated
    USER_LINES="$(grep '^\*\*User:\*\*' "$file" | head -3 | sed 's/\*\*User:\*\* /  > /' || echo "  > (no user speech)")"
    
    echo "**$TITLE**"
    echo "$USER_LINES"
    echo ""
  done
done

# Summary stats
TOTAL=$(echo "$FILES" | wc -w)
echo "---"
echo "Total: $TOTAL transcripts"
echo ""

# Show classification distribution from state
python3 -c "
import json, sys
with open('$STATE_FILE') as f:
    state = json.load(f)
convs = state.get('conversations', {})
today = {k:v for k,v in convs.items() if v.get('file','').startswith('$DATE')}
from collections import Counter
dist = Counter(v.get('classification','unknown') for v in today.values())
for cls, count in sorted(dist.items(), key=lambda x: -x[1]):
    print(f'  {cls}: {count}')
" 2>/dev/null || true
