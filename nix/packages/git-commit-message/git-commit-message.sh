#!/usr/bin/env bash

# git-commit-message.sh - Generate git commit messages using Claude Code
# Usage: ./git-commit-message.sh [--accept] [--quiet]
#   --accept  Automatically accept the generated commit message
#   --quiet   Suppress verbose output

set -eo pipefail

# Process command line arguments
ACCEPT=false
QUIET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --accept)
      ACCEPT=true
      shift
      ;;
    --quiet)
      QUIET=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--accept] [--quiet]"
      exit 1
      ;;
  esac
done

# Check if claude-code is installed
if ! command -v claude &>/dev/null; then
  echo "Warning: Claude Code CLI not found. This tool requires Claude Code CLI to be installed separately."
  echo "Please install Claude Code CLI from: https://github.com/anthropics/claude-code"
  echo "Continuing anyway for testing purposes..."
  # Don't exit here, to allow building and installation even without Claude CLI
fi

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "Error: Not inside a git repository."
  exit 1
fi

# Get git diff for staged changes
DIFF=$(git diff --staged)

if [ "$DIFF" = "" ]; then
  if [ "$QUIET" = false ]; then
    echo "No staged changes found. Automatically staging all changes..."
  fi
  git add -A
  DIFF=$(git diff --staged)

  # Check again if there's anything to commit
  if [ "$DIFF" = "" ]; then
    echo "No changes to commit after staging all files."
    exit 1
  fi
fi

# System prompt to instruct Claude on how to generate commit messages
SYSTEM_PROMPT='You are CommitGPT, a specialized assistant for generating high-quality git commit messages. Your task is to analyze the git diff and suggest a concise, descriptive commit message following conventional commit format.

Guidelines for commit messages:
- Follow conventional commits format: <type>(<scope>): <description>
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore
- Keep the first line under 72 characters
- Be specific about what changed and why
- Focus on the "why" not just the "what"
- Use present tense, imperative mood (e.g., "add" not "added")
- No period at the end of the first line

You will receive a git diff as input. Analyze it carefully and respond ONLY with the suggested commit message, nothing else. No explanations, no discussions, just the commit message.

Example output:
feat(auth): implement OAuth2 login with Google provider'

# User prompt to send the diff to Claude
USER_PROMPT="Here is the git diff for staged changes. Generate a concise, descriptive commit message following conventional commits format:

\`\`\`
$DIFF
\`\`\`"

# Call Claude Code with stream-json and show output in real-time
if [ "$QUIET" = false ]; then
  echo -e "\nStreaming JSON output:"
  claude --print "$USER_PROMPT" --system-prompt "$SYSTEM_PROMPT" --output-format stream-json | tee /tmp/commit_message_response.json
else
  claude --print "$USER_PROMPT" --system-prompt "$SYSTEM_PROMPT" --output-format stream-json > /tmp/commit_message_response.json
fi

# Read the saved response for the commit message
COMMIT_MESSAGE=$(cat /tmp/commit_message_response.json | tail -1 | jq -r '.completion')

if [ "$QUIET" = false ]; then
  echo -e "\nGenerated commit message: $COMMIT_MESSAGE"
fi

# Check if we should auto-accept the commit message
if [ "$ACCEPT" = true ]; then
  git commit -m "$COMMIT_MESSAGE"
  if [ "$QUIET" = false ]; then
    echo "Changes committed successfully with message: $COMMIT_MESSAGE"
  fi
else
  # Ask user if they want to use this message
  read -p "Use this commit message? (y/n/e for edit): " CHOICE

  case "$CHOICE" in
  y | Y)
    git commit -m "$COMMIT_MESSAGE"
    if [ "$QUIET" = false ]; then
      echo "Changes committed successfully!"
    fi
    ;;
  e | E)
    # Create a temporary file with the commit message
    TEMP_FILE=$(mktemp)
    echo "$COMMIT_MESSAGE" >"$TEMP_FILE"

    # Open the file in the default editor
    "${EDITOR:-vim}" "$TEMP_FILE"

    # Read the edited message and commit
    EDITED_MESSAGE=$(cat "$TEMP_FILE")
    rm "$TEMP_FILE"

    git commit -m "$EDITED_MESSAGE"
    if [ "$QUIET" = false ]; then
      echo "Changes committed with edited message!"
    fi
    ;;
  *)
    if [ "$QUIET" = false ]; then
      echo "Commit aborted. You can create your own commit message with 'git commit'."
    fi
    ;;
  esac
fi