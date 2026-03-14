
# Show daily nutrition totals
# Usage: daily-summary.sh [YYYY-MM-DD]


DATE="${1:-$(date +%Y-%m-%d)}"
LOG_FILE="${HOME}/nutrition/log.jsonl"
FOODS_FILE="${HOME}/nutrition/foods.yaml"
MEALS_FILE="${HOME}/nutrition/meals.yaml"
TARGETS_FILE="${HOME}/nutrition/targets.yaml"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "No log file found"
  exit 0
fi

# Extract today's entries
TODAY_ENTRIES=$(grep "\"${DATE}" "$LOG_FILE" || true)

if [[ -z "$TODAY_ENTRIES" ]]; then
  echo "No entries for ${DATE}"
  exit 0
fi

# Python does the heavy lifting — resolves meals/items against foods.yaml
python3 - "$DATE" "$FOODS_FILE" "$MEALS_FILE" "$TARGETS_FILE" <<'PYEOF'
import json, sys, subprocess, yaml
from pathlib import Path

date = sys.argv[1]
foods_file = sys.argv[2]
meals_file = sys.argv[3]
targets_file = sys.argv[4]
log_file = Path.home() / "nutrition" / "log.jsonl"

with open(foods_file) as f:
    foods = yaml.safe_load(f) or {}
with open(meals_file) as f:
    meals = yaml.safe_load(f) or {}
with open(targets_file) as f:
    targets = yaml.safe_load(f) or {}

totals = {"cal": 0, "fat": 0, "protein": 0, "net_carbs": 0, "fiber": 0}
micro_totals = {}
entries = []

with open(log_file) as f:
    for line in f:
        entry = json.loads(line.strip())
        if not entry.get("ts", "").startswith(date):
            continue
        entries.append(entry)

def add_food(food_id, qty):
    if food_id not in foods:
        print(f"  ⚠ Unknown food: {food_id}", file=sys.stderr)
        return
    fd = foods[food_id]
    m = fd.get("macros", {})
    for k in totals:
        totals[k] += m.get(k, 0) * qty
    for mk, mv in fd.get("micros", {}).items():
        micro_totals[mk] = micro_totals.get(mk, 0) + mv * qty

for entry in entries:
    if "meal" in entry:
        meal = meals.get(entry["meal"], {})
        for item in meal.get("items", []):
            add_food(item["food"], item.get("qty", 1))
    elif "items" in entry:
        for item in entry["items"]:
            add_food(item["food"], item.get("qty", 1))
    elif "note" in entry:
        print(f"  📝 Note: {entry['note']}")

# Print macros
print(f"\n📊 {date} — Daily Totals")
print(f"{'─' * 40}")
mt = targets.get("macros", {})
print(f"  Calories:   {totals['cal']:>7.0f} / {mt.get('calories', '?')}")
print(f"  Fat:        {totals['fat']:>7.1f}g / {mt.get('fat_g', '?')}g")
print(f"  Protein:    {totals['protein']:>7.1f}g / {mt.get('protein_g', '?')}g")
print(f"  Net Carbs:  {totals['net_carbs']:>7.1f}g / {mt.get('net_carbs_g', '?')}g")
print(f"  Fiber:      {totals['fiber']:>7.1f}g / {mt.get('fiber_g', '?')}g")

# Print key micros
if micro_totals:
    mict = targets.get("micros", {})
    print(f"\n🔬 Key Micros")
    print(f"{'─' * 40}")
    for key in ["sodium_mg", "potassium_mg", "magnesium_mg", "calcium_mg",
                 "vitamin_d_mcg", "vitamin_b12_mcg", "vitamin_k_mcg",
                 "iron_mg", "zinc_mg", "selenium_mcg"]:
        if key in micro_totals:
            unit = "mcg" if "mcg" in key else "mg"
            name = key.replace("_mg", "").replace("_mcg", "").replace("_", " ").title()
            target_val = mict.get(key, "?")
            print(f"  {name:<16} {micro_totals[key]:>7.1f}{unit} / {target_val}{unit}")
PYEOF
