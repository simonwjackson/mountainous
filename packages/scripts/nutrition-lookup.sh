
# Lookup food from multiple sources (USDA first, then Open Food Facts)
# Usage: lookup.sh "search term"
#        lookup.sh --barcode "012345678901"


# Load API keys
[[ -f /run/agenix/nutrition-api-keys ]] && source /run/agenix/nutrition-api-keys

USDA_API="https://api.nal.usda.gov/fdc/v1"
USDA_KEY="${USDA_API_KEY:-DEMO_KEY}"
OFF_API="https://world.openfoodfacts.org/api/v2"
FS_API="https://platform.fatsecret.com/rest/server.api"

usage() {
  echo "Usage: $0 <search term>"
  echo "       $0 --barcode <barcode>"
  exit 1
}

search_usda() {
  local query="$1"
  local result
  result=$(curl -s "${USDA_API}/foods/search?api_key=${USDA_KEY}&query=$(jq -rn --arg q "$query" '$q | @uri')&pageSize=5&dataType=SR%20Legacy,Foundation" \
    -H "Content-Type: application/json")

  echo "$result" | jq -r '
    .foods[:5][] | {
      source: "usda",
      id: (.fdcId | tostring),
      name: .description,
      serving_g: (if .servingSize then .servingSize else null end),
      serving_unit: (if .servingSizeUnit then .servingSizeUnit else null end),
      nutrients: [.foodNutrients[] | {
        name: .nutrientName,
        value: .value,
        unit: .unitName
      }]
    }
  '
}

search_off() {
  local query="$1"
  curl -s "https://world.openfoodfacts.org/cgi/search.pl?search_terms=${query// /+}&search_simple=1&action=process&json=1&page_size=5&fields=code,product_name,nutriments,serving_size" |
    jq -r '
      .products[:5][] | select(.product_name != null and .product_name != "") | {
        source: "openfoodfacts",
        id: .code,
        name: .product_name,
        serving: .serving_size,
        nutrients: {
          calories: .nutriments."energy-kcal_100g",
          fat: .nutriments.fat_100g,
          protein: .nutriments.proteins_100g,
          carbs: .nutriments.carbohydrates_100g,
          fiber: .nutriments.fiber_100g,
          sodium_mg: ((.nutriments.sodium_100g // 0) * 1000 | floor)
        }
      }
    '
}

barcode_off() {
  local code="$1"
  curl -s "${OFF_API}/product/${code}?fields=code,product_name,nutriments,serving_size,serving_quantity" |
    jq -r '
      .product | {
        source: "openfoodfacts",
        id: .code,
        name: .product_name,
        serving: .serving_size,
        serving_g: .serving_quantity,
        nutrients: {
          calories: .nutriments."energy-kcal_100g",
          fat: .nutriments.fat_100g,
          protein: .nutriments.proteins_100g,
          carbs: .nutriments.carbohydrates_100g,
          fiber: .nutriments.fiber_100g,
          sodium_mg: ((.nutriments.sodium_100g // 0) * 1000)
        }
      }
    '
}

get_fatsecret_token() {
  # OAuth2 client credentials flow
  local token_resp
  token_resp=$(curl -s -X POST "https://oauth.fatsecret.com/connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&scope=basic" \
    -u "${FATSECRET_KEY}:${FATSECRET_SECRET}")
  echo "$token_resp" | jq -r '.access_token'
}

search_fatsecret() {
  local query="$1"
  local token
  token=$(get_fatsecret_token)
  if [[ "$token" == "null" || -z "$token" ]]; then
    echo "Error: FatSecret auth failed" >&2
    return 1
  fi
  local resp
  resp=$(curl -s "${FS_API}?method=foods.search&search_expression=$(jq -rn --arg q "$query" '$q | @uri')&format=json&max_results=5" \
    -H "Authorization: Bearer ${token}")
  if echo "$resp" | jq -e '.error' > /dev/null 2>&1; then
    echo "$resp" | jq -r '"Error: " + .error.message' >&2
    return 1
  fi
  echo "$resp" | jq -r '
    [.foods.food] | flatten | .[:5][] | {
      source: "fatsecret",
      id: .food_id,
      name: .food_name,
      description: .food_description
    }
  '
}

if [[ $# -lt 1 ]]; then
  usage
fi

if [[ "$1" == "--barcode" ]]; then
  [[ $# -lt 2 ]] && usage
  echo "=== Open Food Facts (barcode) ==="
  barcode_off "$2"
else
  query="$*"
  echo "=== USDA FoodData Central ==="
  search_usda "$query"
  echo ""
  echo "=== Open Food Facts ==="
  search_off "$query"
  echo ""
  echo "=== FatSecret ==="
  search_fatsecret "$query"
fi
