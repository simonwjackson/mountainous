#!/usr/bin/env bash

set -euo pipefail

# Default mode
MODE="changed"

# Parse command line arguments
if [ $# -gt 0 ]; then
  case "$1" in
  "changed" | "modified" | "staged" | "diverged")
    MODE="$1"
    ;;
  *)
    echo "Usage: $0 [changed|modified|staged|diverged]"
    echo "  changed     - Scan uncommitted changes (tracked + untracked files) (default)"
    echo "  modified    - Scan uncommitted changes in tracked files only"
    echo "  staged      - Scan staged changes ready to be committed"
    echo "  diverged    - Scan changes between current branch and upstream"
    exit 1
    ;;
  esac
fi

# Get the appropriate git diff based on mode
get_diff() {
  case "$MODE" in
  "changed")
    # Show both tracked changes and new untracked files
    git diff
    git ls-files --others --exclude-standard | xargs -I {} git diff /dev/null {} 2>/dev/null || true
    ;;
  "modified")
    git diff
    ;;
  "staged")
    git diff --cached
    ;;
  "diverged")
    # Check if upstream exists
    if ! git rev-parse @{u} >/dev/null 2>&1; then
      echo "Error: No upstream branch configured for current branch"
      echo "Set upstream with: git branch --set-upstream-to=<remote>/<branch>"
      exit 1
    fi
    git diff @{u}...HEAD
    ;;
  esac
}

# Get the diff content
diff_content=$(get_diff)

# Check if there's any diff content
if [ "$diff_content" = "" ]; then
  echo "No changes detected for mode: $MODE"
  exit 0
fi

# Scan the diff for secrets
scan_result=$(echo "$diff_content" |
  gum spin --spinner dot --title "Scanning for secrets..." -- \
  bun x @anthropic-ai/claude-code \
    --model claude-3-5-haiku-latest \
    --print \
    "Scan this git diff for exposed secrets, API keys, passwords, private keys, tokens, or other sensitive information. 
  
  Look for patterns like:
  - API keys (starts with 'sk-', 'pk-', 'API_KEY', etc.)
  - Database passwords or connection strings
  - Private keys (BEGIN PRIVATE KEY, BEGIN RSA PRIVATE KEY)
  - OAuth tokens or secrets
  - AWS access keys
  - JWT tokens
  - Hardcoded passwords
  
  If you find ANY potential security issues, respond with 'SECURITY_ISSUE_FOUND: [description]' and I will exit with code 1.
  If the diff is clean, respond with 'CLEAN: No security issues detected'.")

# Display the scan result
echo "$scan_result"

# Exit with appropriate code based on scan result
if echo "$scan_result" | grep -q "SECURITY_ISSUE_FOUND"; then
  exit 1
else
  exit 0
fi
