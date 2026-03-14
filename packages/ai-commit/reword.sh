#!/usr/bin/env bash
# reword.sh - Reword a commit message using AI
# Usage: ai-reword <commit-sha>
# Generates an AI commit message based on the commit's diff and rewords it

set -euo pipefail

# Parse arguments
COMMIT_SHA="${1:-}"
LOG_LEVEL="${LOG_LEVEL:-}"

shift || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --log)
      LOG_LEVEL="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# Helper functions
log_info() {
  if [[ "$LOG_LEVEL" == "info" || "$LOG_LEVEL" == "debug" || "$LOG_LEVEL" == "trace" ]]; then
    echo "$@" >&2
  fi
}

log_error() {
  echo "$@" >&2
}

# Validate commit SHA
if [ -z "$COMMIT_SHA" ]; then
  log_error "Error: No commit SHA provided"
  log_error "Usage: ai-reword <commit-sha>"
  exit 1
fi

# Verify the commit exists
if ! git rev-parse --verify "$COMMIT_SHA^{commit}" &>/dev/null; then
  log_error "Error: Invalid commit SHA: $COMMIT_SHA"
  exit 1
fi

# Get the full SHA
FULL_SHA=$(git rev-parse "$COMMIT_SHA")

log_info "🔍 Analyzing commit $FULL_SHA..."

# Get the diff for this specific commit
DIFF=$(git show --format="" "$FULL_SHA")

if [ -z "$DIFF" ]; then
  log_error "Error: No diff found for commit $FULL_SHA"
  exit 1
fi

log_info "🤖 Generating AI commit message..."

# Generate commit message using Claude
MESSAGE=$(echo "$DIFF" | bun x '@anthropic-ai/claude-code' --print \
  --model haiku \
  --verbose \
  --output-format stream-json \
  --include-partial-messages \
  --mcp-config "" \
  --strict-mcp-config \
  --setting-sources "" \
  --dangerously-skip-permissions \
  --tools "" \
  --system-prompt "Generate only a Conventional Commits message. No explanation. No markdown formatting or code blocks." \
  "Generate commit message: type(scope): subject. Present tense, lowercase, 50 chars max. Do not wrap in backticks or code blocks." \
  2>/dev/null |
  jq -r 'select(.type == "stream_event") | .event | select(.type == "content_block_delta") | .delta.text // empty' |
  tr -d '\n')

# Strip any markdown code blocks that might have been added
# shellcheck disable=SC2016
MESSAGE=$(echo "$MESSAGE" | sed 's/^```[a-zA-Z]*//; s/```$//' | sed 's/^`//; s/`$//')

# Validate message
if [ -z "$MESSAGE" ]; then
  log_error "Error: Failed to generate commit message"
  exit 1
fi

log_info "✓ Generated message: $MESSAGE"

# Check if this is HEAD
HEAD_SHA=$(git rev-parse HEAD)

if [ "$FULL_SHA" = "$HEAD_SHA" ]; then
  # Simple case: amend HEAD
  log_info "📝 Amending HEAD commit..."
  git commit --amend -m "$MESSAGE"
  echo "✓ Rewrote HEAD commit: $MESSAGE"
else
  # Complex case: rebase to reword an older commit
  log_info "📝 Rebasing to reword commit..."
  
  # Find the parent of the target commit for rebase
  PARENT_SHA=$(git rev-parse "$FULL_SHA^")
  
  # Create a temporary script for GIT_SEQUENCE_EDITOR that changes 'pick' to 'reword' for our commit
  TEMP_SCRIPT=$(mktemp)
  cat > "$TEMP_SCRIPT" << 'SCRIPT_EOF'
#!/usr/bin/env bash
# Change 'pick <sha>' to 'reword <sha>' for our target commit
sed -i "s/^pick $1/reword $1/" "$2"
SCRIPT_EOF
  chmod +x "$TEMP_SCRIPT"
  
  # Create a temporary script for GIT_EDITOR that provides our message
  EDITOR_SCRIPT=$(mktemp)
  cat > "$EDITOR_SCRIPT" << EDITOR_EOF
#!/usr/bin/env bash
# Write the new commit message to the file
echo "$MESSAGE" > "\$1"
EDITOR_EOF
  chmod +x "$EDITOR_SCRIPT"
  
  # Perform the rebase
  # GIT_SEQUENCE_EDITOR handles the todo list (pick -> reword)
  # GIT_EDITOR handles providing the new message
  if GIT_SEQUENCE_EDITOR="$TEMP_SCRIPT ${FULL_SHA:0:7}" \
     GIT_EDITOR="$EDITOR_SCRIPT" \
     git rebase -i "$PARENT_SHA" 2>/dev/null; then
    echo "✓ Rewrote commit ${FULL_SHA:0:7}: $MESSAGE"
  else
    log_error "Error: Rebase failed. You may need to resolve conflicts manually."
    log_error "Run 'git rebase --abort' to cancel."
    rm -f "$TEMP_SCRIPT" "$EDITOR_SCRIPT"
    exit 1
  fi
  
  # Cleanup
  rm -f "$TEMP_SCRIPT" "$EDITOR_SCRIPT"
fi
