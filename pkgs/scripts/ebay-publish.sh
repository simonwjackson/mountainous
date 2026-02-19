#!/usr/bin/env bash
# eBay Listing Publisher
# Usage: ./publish.sh <listing.json> [--draft|--publish]
# Requires: curl, jq
# Reads credentials from agenix (/run/agenix/) or ~/.secrets/ fallback

set -euo pipefail

LISTING_FILE="${1:?Usage: $0 <listing.json> [--draft|--publish]}"
MODE="${2:---draft}"

# Load credentials
if [[ -f /run/agenix/ebay-api-env ]]; then
  source /run/agenix/ebay-api-env
else
  source ~/.secrets/ebay-api.env
fi

if [[ -f /run/agenix/ebay-refresh-token ]]; then
  source /run/agenix/ebay-refresh-token
fi

TOKEN_CACHE="/tmp/ebay-access-token.json"

# Get fresh access token using refresh token
refresh_token() {
  local AUTH
  AUTH=$(echo -n "${EBAY_APP_ID}:${EBAY_CERT_ID}" | base64 -w0)

  curl -s -X POST https://api.ebay.com/identity/v1/oauth2/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "Authorization: Basic ${AUTH}" \
    -d "grant_type=refresh_token" \
    -d "refresh_token=${EBAY_REFRESH_TOKEN}" \
    --data-urlencode "scope=https://api.ebay.com/oauth/api_scope https://api.ebay.com/oauth/api_scope/sell.inventory https://api.ebay.com/oauth/api_scope/sell.account https://api.ebay.com/oauth/api_scope/sell.fulfillment" \
    > "$TOKEN_CACHE"

  if ! jq -e .access_token "$TOKEN_CACHE" > /dev/null 2>&1; then
    echo "ERROR: Failed to refresh token" >&2
    cat "$TOKEN_CACHE" >&2
    exit 1
  fi
}

get_token() {
  # Re-use cached token if less than 1 hour old
  if [[ -f "$TOKEN_CACHE" ]] && [[ $(find "$TOKEN_CACHE" -mmin -55 2>/dev/null) ]]; then
    jq -r .access_token "$TOKEN_CACHE"
  else
    refresh_token
    jq -r .access_token "$TOKEN_CACHE"
  fi
}

api() {
  local method="$1" url="$2"
  shift 2
  local TOKEN
  TOKEN=$(get_token)
  curl -s -X "$method" "$url" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "Content-Language: en-US" \
    -H "X-EBAY-C-MARKETPLACE-ID: EBAY_US" \
    "$@"
}

# Parse listing JSON
LISTING=$(cat "$LISTING_FILE")
SKU=$(echo "$LISTING" | jq -r '.listing.itemSpecifics.MPN // "ITEM-001"')
TITLE=$(echo "$LISTING" | jq -r '.listing.title')
PRICE=$(echo "$LISTING" | jq -r '.listing.price')
CONDITION=$(echo "$LISTING" | jq -r '.listing.condition')
CONDITION_DESC=$(echo "$LISTING" | jq -r '.listing.conditionDescription')
CATEGORY_ID=$(echo "$LISTING" | jq -r '.listing.categoryId')
DESCRIPTION=$(echo "$LISTING" | jq -r '.listing.description')

echo "=== eBay Listing Publisher ==="
echo "Title: $TITLE"
echo "Price: \$$PRICE"
echo "SKU: $SKU"
echo "Mode: $MODE"
echo ""

# Step 1: Create/update inventory item
echo "Step 1: Creating inventory item..."
INVENTORY_BODY=$(jq -n \
  --arg title "$TITLE" \
  --arg desc "$DESCRIPTION" \
  --arg condDesc "$CONDITION_DESC" \
  --argjson specs "$(echo "$LISTING" | jq '.listing.itemSpecifics | to_entries | map({name: .key, values: [.value]})')" \
  '{
    product: {
      title: $title,
      description: $desc,
      aspects: ($specs | reduce .[] as $s ({}; . + {($s.name): $s.values}))
    },
    condition: "USED_EXCELLENT",
    conditionDescription: $condDesc,
    availability: {
      shipToLocationAvailability: {
        quantity: 1
      }
    }
  }')

RESULT=$(api PUT "https://api.ebay.com/sell/inventory/v1/inventory_item/$SKU" -d "$INVENTORY_BODY" -w "\n%{http_code}")
HTTP_CODE=$(echo "$RESULT" | tail -1)
BODY=$(echo "$RESULT" | sed '$d')

if [[ "$HTTP_CODE" =~ ^2 ]]; then
  echo "  ✅ Inventory item created/updated (HTTP $HTTP_CODE)"
else
  echo "  ❌ Failed (HTTP $HTTP_CODE): $BODY"
  exit 1
fi

# Step 2: Create offer
echo "Step 2: Creating offer..."
OFFER_BODY=$(jq -n \
  --arg sku "$SKU" \
  --arg catId "$CATEGORY_ID" \
  --argjson price "$PRICE" \
  '{
    sku: $sku,
    marketplaceId: "EBAY_US",
    format: "FIXED_PRICE",
    listingDescription: null,
    availableQuantity: 1,
    categoryId: $catId,
    pricingSummary: {
      price: {
        value: ($price | tostring),
        currency: "USD"
      },
      bestOfferEnabled: true
    },
    listingPolicies: {
      fulfillmentPolicyId: null,
      paymentPolicyId: null,
      returnPolicyId: null
    },
    merchantLocationKey: null
  }')

RESULT=$(api POST "https://api.ebay.com/sell/inventory/v1/offer" -d "$OFFER_BODY" -w "\n%{http_code}")
HTTP_CODE=$(echo "$RESULT" | tail -1)
BODY=$(echo "$RESULT" | sed '$d')

if [[ "$HTTP_CODE" =~ ^2 ]]; then
  OFFER_ID=$(echo "$BODY" | jq -r '.offerId')
  echo "  ✅ Offer created: $OFFER_ID"
else
  echo "  ⚠️  Offer creation (HTTP $HTTP_CODE): $BODY"
  # Try to get existing offer
  RESULT=$(api GET "https://api.ebay.com/sell/inventory/v1/offer?sku=$SKU")
  OFFER_ID=$(echo "$RESULT" | jq -r '.offers[0].offerId // empty')
  if [[ -n "$OFFER_ID" ]]; then
    echo "  ℹ️  Using existing offer: $OFFER_ID"
  else
    echo "  ❌ No offer found"
    exit 1
  fi
fi

if [[ "$MODE" == "--publish" ]]; then
  echo "Step 3: Publishing offer..."
  RESULT=$(api POST "https://api.ebay.com/sell/inventory/v1/offer/$OFFER_ID/publish" -w "\n%{http_code}")
  HTTP_CODE=$(echo "$RESULT" | tail -1)
  BODY=$(echo "$RESULT" | sed '$d')
  if [[ "$HTTP_CODE" =~ ^2 ]]; then
    LISTING_ID=$(echo "$BODY" | jq -r '.listingId')
    echo "  ✅ Published! Listing ID: $LISTING_ID"
    echo "  🔗 https://www.ebay.com/itm/$LISTING_ID"
  else
    echo "  ❌ Publish failed (HTTP $HTTP_CODE): $BODY"
    exit 1
  fi
else
  echo ""
  echo "Draft created. To publish, run:"
  echo "  $0 $LISTING_FILE --publish"
fi
