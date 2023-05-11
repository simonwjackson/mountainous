#!/usr/bin/env bash
#
set -e

PR_COUNT=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/search/issues?q=type:pr+is:open+review-requested:$GITHUB_USER" | \
  jq '.total_count')

if [ "$PR_COUNT" -gt 0 ]; then
  echo ""
fi
