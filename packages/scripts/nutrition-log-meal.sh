
# Log a meal or food items to log.jsonl
# Usage: log-meal.sh --meal morning-coffee
#        log-meal.sh --items '[{"food":"eggs-whole-large","qty":3},{"food":"bacon-pork","qty":4}]'
#        log-meal.sh --note "dinner out, estimated 800cal 60f 40p 10c"


LOG_FILE="${HOME}/nutrition/log.jsonl"
FOODS_FILE="${HOME}/nutrition/foods.yaml"
MEALS_FILE="${HOME}/nutrition/meals.yaml"

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ "$1" == "--meal" ]]; then
  meal_id="$2"
  # Verify meal exists
  if ! yq -e ".[\"${meal_id}\"]" "$MEALS_FILE" > /dev/null 2>&1; then
    echo "Error: meal '${meal_id}' not found in meals.yaml" >&2
    exit 1
  fi
  echo "{\"ts\":\"${ts}\",\"meal\":\"${meal_id}\"}" >> "$LOG_FILE"
  echo "Logged meal: ${meal_id}"

elif [[ "$1" == "--items" ]]; then
  items="$2"
  # Validate each food exists
  for food in $(echo "$items" | jq -r '.[].food'); do
    if ! yq -e ".[\"${food}\"]" "$FOODS_FILE" > /dev/null 2>&1; then
      echo "Warning: food '${food}' not in foods.yaml (log anyway)" >&2
    fi
  done
  echo "{\"ts\":\"${ts}\",\"items\":${items}}" >> "$LOG_FILE"
  echo "Logged items"

elif [[ "$1" == "--note" ]]; then
  note="$2"
  echo "{\"ts\":\"${ts}\",\"note\":$(echo "$note" | jq -Rs .)}" >> "$LOG_FILE"
  echo "Logged note"

else
  echo "Usage: log-meal.sh --meal <meal-id>"
  echo "       log-meal.sh --items '<json array>'"
  echo "       log-meal.sh --note 'free text estimate'"
  exit 1
fi
