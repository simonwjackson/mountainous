#!/usr/bin/env bash
# Load eBay API credentials from agenix-managed secrets
# After nixos-rebuild, secrets decrypt to /run/agenix/

AGENIX_API="/run/agenix/ebay-api-env"
AGENIX_TOKEN="/run/agenix/ebay-refresh-token"

# Fallback to ~/.secrets if agenix paths don't exist yet (pre-rebuild)
if [[ -f "$AGENIX_API" ]]; then
  source "$AGENIX_API"
else
  source ~/.secrets/ebay-api.env 2>/dev/null
fi

if [[ -f "$AGENIX_TOKEN" ]]; then
  source "$AGENIX_TOKEN"
else
  EBAY_REFRESH_TOKEN=$(jq -r '.refresh_token' ~/.secrets/ebay-tokens.json 2>/dev/null)
fi

export EBAY_APP_ID EBAY_DEV_ID EBAY_CERT_ID EBAY_RUNAME EBAY_REFRESH_TOKEN

# If called with args, exec them with the env vars
if [[ $# -gt 0 ]]; then
  exec "$@"
fi
