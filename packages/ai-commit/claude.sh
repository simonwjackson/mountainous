#!/usr/bin/env bash
# claude.sh - Generate commit messages using Claude/Anthropic API
# Expects git diff content via stdin
# Outputs commit message to stdout
# Exit 0 on success, non-zero on failure

set -euo pipefail

# Parse arguments for --log flag
LOG_LEVEL="${LOG_LEVEL:-}"
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

# Helper function for conditional logging
log_info() {
  if [[ "$LOG_LEVEL" == "info" || "$LOG_LEVEL" == "debug" || "$LOG_LEVEL" == "trace" ]]; then
    echo "$@" >&2
  fi
}

log_error() {
  echo "$@" >&2
}

# Read the diff from stdin
DIFF=$(cat)

if [ -z "$DIFF" ]; then
  log_error "Error: No diff content provided"
  exit 1
fi

log_info "🤖 Generating commit message with Claude..."

# Generate commit message based on log level
case "$LOG_LEVEL" in
  trace)
    # Show raw JSONL stream
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
      "Generate commit message: type(scope): subject. Present tense, lowercase, 50 chars max. Do not wrap in backticks or code blocks." |
      tee >(cat >&2) |
      jq -r 'select(.type == "stream_event") | .event | select(.type == "content_block_delta") | .delta.text // empty' |
      tr -d '\n')
    # Strip any markdown code blocks that might have been added
    MESSAGE=$(echo "$MESSAGE" | sed 's/^```[a-zA-Z]*//; s/```$//' | sed 's/^`//; s/`$//')
    echo "" >&2
    ;;
  debug)
    # Show formatted messages from JSONL (streaming text on same line)
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
      "Generate commit message: type(scope): subject. Present tense, lowercase, 50 chars max. Do not wrap in backticks or code blocks." |
      tee >(
        jq -r 'select(.type == "stream_event") | .event | select(.type == "content_block_delta") | .delta.text // empty' | while IFS= read -r chunk; do printf '%s' "$chunk" >&2; done
        echo "" >&2
      ) |
      jq -r 'select(.type == "stream_event") | .event | select(.type == "content_block_delta") | .delta.text // empty' |
      tr -d '\n')
    # Strip any markdown code blocks that might have been added
    MESSAGE=$(echo "$MESSAGE" | sed 's/^```[a-zA-Z]*//; s/```$//' | sed 's/^`//; s/`$//')
    ;;
  info)
    # Show only friendly messages, suppress JSONL
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
      "Generate commit message: type(scope): subject. Present tense, lowercase, 50 chars max. Do not wrap in backticks or code blocks." |
      jq -r 'select(.type == "stream_event") | .event | select(.type == "content_block_delta") | .delta.text // empty' |
      tr -d '\n')
    # Strip any markdown code blocks that might have been added
    MESSAGE=$(echo "$MESSAGE" | sed 's/^```[a-zA-Z]*//; s/```$//' | sed 's/^`//; s/`$//')
    ;;
  *)
    # No logging except errors
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
    MESSAGE=$(echo "$MESSAGE" | sed 's/^```[a-zA-Z]*//; s/```$//' | sed 's/^`//; s/`$//')
    ;;
esac

# Validate message
if [ -z "$MESSAGE" ]; then
  log_error "Error: Failed to generate commit message with Claude"
  exit 1
fi

log_info "✓ Claude commit message: $MESSAGE"

# Output the message to stdout
echo "$MESSAGE"
