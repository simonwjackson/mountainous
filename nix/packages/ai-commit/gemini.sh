#!/usr/bin/env bash
# gemini.sh - Generate commit messages using Gemini API
# Expects git diff content via stdin
# Outputs commit message to stdout
# Exit 0 on success, non-zero on failure

set -euo pipefail

# Parse arguments
DETAILED=false
RETRY_COUNT=3
COMMIT_COUNT=3
STYLE_OVERRIDE=""
LOG_LEVEL="${LOG_LEVEL:-}"

while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--details)
      DETAILED=true
      shift
      ;;
    -r|--retry)
      shift
      RETRY_COUNT="$1"
      shift
      ;;
    --retry=*)
      RETRY_COUNT="${1#*=}"
      shift
      ;;
    -s|--style)
      shift
      STYLE_OVERRIDE="$1"
      shift
      ;;
    --style=*)
      STYLE_OVERRIDE="${1#*=}"
      shift
      ;;
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

# Function to detect commit style from recent commits
detect_commit_style() {
  local commit_count=${1:-10}
  local commits
  commits=$(git log --format="%s" -"$commit_count" 2>/dev/null)

  if [ "$commits" = "" ]; then
    echo "angular:0"
    return
  fi

  # Count different commit patterns
  local angular_count=0
  local imperative_count=0
  local total_count=0

  # Common Angular/Conventional types
  local types="feat|fix|docs|style|refactor|test|chore|build|ci|perf|revert"

  while IFS= read -r commit; do
    ((total_count++))

    # Check for Angular/Conventional pattern: type(scope): description or type: description
    if [[ "$commit" =~ ^($types)(\([^\)]+\))?:[[:space:]] ]]; then
      ((angular_count++))
    # Check for simple imperative style (starts with capital verb)
    elif [[ "$commit" =~ ^[A-Z][a-z]+[[:space:]] ]]; then
      ((imperative_count++))
    fi
  done <<<"$commits"

  # Calculate confidence (percentage of commits following detected pattern)
  local style="angular"
  local confidence=0

  if [ "$total_count" -gt 0 ]; then
    local angular_pct=$((angular_count * 100 / total_count))
    local imperative_pct=$((imperative_count * 100 / total_count))

    if [ "$angular_pct" -ge 70 ]; then
      style="angular"
      confidence=$angular_pct
    elif [ "$imperative_pct" -ge 70 ]; then
      style="imperative"
      confidence=$imperative_pct
    else
      # Default to angular with low confidence
      style="angular"
      confidence=$angular_pct
    fi
  fi

  echo "${style}:${confidence}"
}

# Function to get example commits for the detected style
get_style_examples() {
  local style=$1
  local count=${2:-3}

  case $style in
  "angular")
    git log --format="%s" -50 2>/dev/null | grep -E "^(feat|fix|docs|style|refactor|test|chore|build|ci|perf)(\([^\)]+\))?:[[:space:]]" | head -"$count"
    ;;
  "imperative")
    git log --format="%s" -50 2>/dev/null | grep -E "^[A-Z][a-z]+[[:space:]]" | grep -v -E "^(feat|fix|docs|style|refactor|test|chore|build|ci|perf)" | head -"$count"
    ;;
  *)
    git log --format="%s" -"$count" 2>/dev/null
    ;;
  esac
}

# Function to analyze commit types used in the repository
analyze_commit_types() {
  git log --format="%s" -100 2>/dev/null |
    grep -E "^(feat|fix|docs|style|refactor|test|chore|build|ci|perf)" |
    awk -F'[:(]' '{print $1}' |
    sort | uniq -c | sort -rn |
    head -5 |
    awk '{types=types sep $2; sep=", "} END {print types}'
}

# Read staged diff and files from stdin
STAGED_CONTENT=$(cat)

if [ -z "$STAGED_CONTENT" ]; then
  log_error "Error: No diff content provided"
  exit 1
fi

# Extract file list from diff (simple name-status style parsing)
STAGED_DIFF=$(echo "$STAGED_CONTENT" | grep -E '^\+\+\+|^---' | sed 's/^[+\-]\+\+ [ab]\///' | sort -u | awk '{printf "M\t%s\n", $0}')

# Check for Gemini API key from agenix
API_KEY_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/agenix/user-simonwjackson-gemini-api-key"

if [ ! -f "$API_KEY_FILE" ]; then
  log_error "Error: Gemini API key not found at $API_KEY_FILE"
  log_error "Make sure agenix is properly configured and the secret is available."
  exit 1
fi

API_KEY=$(cat "$API_KEY_FILE")

if [ -z "$API_KEY" ]; then
  log_error "Error: Gemini API key is empty"
  exit 1
fi

log_info "🤖 Generating commit message with Gemini..."

# Detect commit style from recent commits
if [ "$STYLE_OVERRIDE" != "" ]; then
  # Use manual override
  COMMIT_STYLE="$STYLE_OVERRIDE"
  CONFIDENCE=100
  log_info "Using manual style override: $COMMIT_STYLE"
else
  log_info "Analyzing commit style from recent commits..."
  STYLE_INFO=$(detect_commit_style "$COMMIT_COUNT")
  COMMIT_STYLE=$(echo "$STYLE_INFO" | cut -d: -f1)
  CONFIDENCE=$(echo "$STYLE_INFO" | cut -d: -f2)

  log_info "Detected style: $COMMIT_STYLE (confidence: ${CONFIDENCE}%)"
fi

# Get examples and common types
EXAMPLES=$(get_style_examples "$COMMIT_STYLE" 5)
if [ "$COMMIT_STYLE" = "angular" ]; then
  COMMON_TYPES=$(analyze_commit_types)
  if [ "$COMMON_TYPES" = "" ]; then
    COMMON_TYPES="feat, fix, refactor, style, docs"
  fi
fi

# Create prompt for Gemini based on detected style
if [ "$COMMIT_STYLE" = "angular" ] && [ "$CONFIDENCE" -ge 70 ]; then
  # Use Angular style with repository-specific examples
  if [[ "$DETAILED" == true ]]; then
    PROMPT="Generate a detailed Angular-style commit message for these staged git changes.

This repository uses Angular commit convention. Recent examples from this repo:
$EXAMPLES

Common types used in this repo: $COMMON_TYPES

Files changed:
$STAGED_DIFF

Diff content:
$STAGED_CONTENT

Format:
type(scope): short description

Detailed explanation in one sentence.

- First bullet point describing a key change
- Second bullet point describing another change
- Third bullet point describing final change

Rules:
- Follow the same Angular format as the examples above
- Use types commonly used in this repo: $COMMON_TYPES
- Keep first line under 50 characters
- One sentence explanation after blank line
- Exactly 3 bullet points with specific details
- Match the style and tone of the example commits"
  else
    PROMPT="Generate an Angular-style commit message for these staged git changes.

This repository uses Angular commit convention. Recent examples from this repo:
$EXAMPLES

Common types used in this repo: $COMMON_TYPES

Files changed:
$STAGED_DIFF

Diff content:
$STAGED_CONTENT

Rules:
- Follow the exact same format as the examples above
- Use types commonly used in this repo: $COMMON_TYPES
- Keep description under 50 characters
- Be specific and concise
- Only return the commit message, nothing else
- Match the style and tone of the example commits"
  fi
elif [ "$COMMIT_STYLE" = "imperative" ] && [ "$CONFIDENCE" -ge 70 ]; then
  # Use imperative style
  if [[ "$DETAILED" == true ]]; then
    PROMPT="Generate a commit message in imperative style for these staged git changes.

This repository uses simple imperative commit messages. Recent examples:
$EXAMPLES

Files changed:
$STAGED_DIFF

Diff content:
$STAGED_CONTENT

Format:
Start with a capital letter verb, followed by what was done

Detailed explanation paragraph.

- First bullet point describing a key change
- Second bullet point describing another change
- Third bullet point describing final change

Rules:
- Start with imperative verb (Add, Fix, Update, Remove, etc.)
- Keep first line under 50 characters
- Match the style of the examples above
- Include detailed explanation and bullet points"
  else
    PROMPT="Generate a commit message in imperative style for these staged git changes.

This repository uses simple imperative commit messages. Recent examples:
$EXAMPLES

Files changed:
$STAGED_DIFF

Diff content:
$STAGED_CONTENT

Rules:
- Start with imperative verb (Add, Fix, Update, Remove, etc.)
- Keep under 50 characters
- Be specific and concise
- Only return the commit message, nothing else
- Match the style of the examples above"
  fi
else
  # Fall back to Angular style (original behavior)
  log_info "Low confidence in detected style. Using Angular convention as default."
  if [[ "$DETAILED" == true ]]; then
    PROMPT="Generate a detailed Angular-style commit message for these staged git changes:

Files changed:
$STAGED_DIFF

Diff content:
$STAGED_CONTENT

Format:
type(scope): short description

Detailed explanation in one sentence.

- First bullet point describing a key change
- Second bullet point describing another change
- Third bullet point describing final change

Rules:
- Use Angular commit format: type(scope): description
- Types: feat, fix, docs, style, refactor, test, chore
- Keep first line under 50 characters
- One sentence explanation after blank line
- Exactly 3 bullet points with specific details
- Be concise but informative"
  else
    PROMPT="Generate an Angular-style commit message for these staged git changes:

Files changed:
$STAGED_DIFF

Diff content:
$STAGED_CONTENT

Rules:
- Use Angular commit format: type(scope): description
- Types: feat, fix, docs, style, refactor, test, chore
- Keep description under 50 characters
- Be specific and concise
- Only return the commit message, nothing else

Examples:
- feat(auth): add user login functionality
- fix(api): resolve timeout issues
- refactor(components): rename plan files"
  fi
fi

# Escape the prompt for JSON
ESCAPED_PROMPT=$(echo "$PROMPT" | jq -Rs .)

# Call Gemini API with retry logic
for ((i = 1; i <= RETRY_COUNT; i++)); do
  log_info "Attempting to generate commit message (attempt $i/$RETRY_COUNT)..."

  RESPONSE=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$API_KEY" \
    -H 'Content-Type: application/json' \
    -X POST \
    -d "{\"contents\":[{\"parts\":[{\"text\":$ESCAPED_PROMPT}]}]}")

  # Extract the commit message from JSON response
  COMMIT_MESSAGE=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text' 2>/dev/null)

  # Remove markdown code blocks if present, but preserve blank lines in commit message
  COMMIT_MESSAGE=$(echo "$COMMIT_MESSAGE" | sed 's/^```[a-zA-Z]*$//' | sed 's/^```$//')

  if [ "$COMMIT_MESSAGE" != "null" ] && [ "$COMMIT_MESSAGE" != "" ]; then
    break
  fi

  if [ "$i" -eq "$RETRY_COUNT" ]; then
    log_error "Error: Failed to generate commit message after $RETRY_COUNT attempts"
    log_error "API Response: $RESPONSE"
    exit 1
  fi

  log_info "Attempt failed, retrying in 2 seconds..."
  sleep 2
done

log_info "✓ Gemini commit message: $COMMIT_MESSAGE"
log_info "(Style: $COMMIT_STYLE, Confidence: ${CONFIDENCE}%)"

# Output the message to stdout
echo "$COMMIT_MESSAGE"
