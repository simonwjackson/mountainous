---
name: nutrition-fitness
description: Log Simon's food, drinks, exercise sets and mood to SparkyFitness whenever he states them, without waiting for a logging request. Read health context for briefs, wind-down and "how am I doing".
---

# Nutrition and fitness

SparkyFitness replaces Logbook. Use the `sparkyfitness` MCP server. A statement
of food or drink consumed is a request to log it, not just calculate it.
"55g heavy cream" means log 55 grams. Do not ask permission first.

Use `sparky_manage_food` action `lookup_food_nutrition` first (USDA and FatSecret
are configured). Use the returned provider, external ID and serving size with
`log_external_food`; convert the stated amount to the provider's units/servings.
For an internal match use `log_food` with its internal food ID. Never pass an
external ID as `food_id`. Never invent nutrition when a lookup works.
When Simon gives exact macros, use `create_food` with `is_quick_food: true`,
the stated quantity/unit, macros and meal/date to log without saving a food.
Omit unknown nutrients; do not turn them into zero.

Use America/Denver for dates and meal_type unless Simon says otherwise:
breakfast before 11:00, lunch 11:00–16:00, dinner 16:00–21:00, snacks otherwise.
Ask only when quantity is truly ambiguous: for "a bowl of chili" with no known
bowl size, ask for its weight or serving size. Do not guess a bowl's macros.
Confirm a successful food log in one short line with kcal and protein.

For completed sets, use `sparky_manage_exercise` action `log_exercise` with
`sets`. "bench 5x5 at 135" means five sets of five reps at 135; use Simon's
known weight unit, or ask if it is unknown. Convert pounds to kilograms for
the tool's `sets[].weight` (135 lb is 61.235 kg). Find the exercise with
`sparky_search_exercises` when needed. Log stated evening charge/mood with
`sparky_manage_checkin` action `log_mood`; preserve his words and use the tool's
mood scale, not an invented conversion. Put words in `notes` when he gives no
number. Confirm each successful log briefly.

For "how am I doing", brief or wind-down context, call
`sparky_get_health_summary` or `sparky_get_daily_report` first. Use fresh data,
not remembered totals. Never claim a failed write succeeded. If a write times
out, check the diary/recent entries before retrying so it is not logged twice.
Do not delete foods or diary entries unless Simon explicitly asks.
