# The SparkyFitness tools flakey may call. One list for both boundaries: the
# production front door's /mcp/sparkyfitness row enforces it, and OpenClaw's
# toolFilter shows it. Profile, medications, photos, integrations and the
# developer and raw-SQL tools stay out. The filter works per tool, not per
# action: the manage tools keep their own write and delete actions.
[
  "sparky_manage_food"
  "sparky_search_foods"
  "sparky_get_food_diary"
  "sparky_get_nutrition_summary"
  "sparky_get_recent_food_entries"
  "sparky_manage_exercise"
  "sparky_get_exercise_diary"
  "sparky_get_exercise_progress"
  "sparky_get_recent_exercise_entries"
  "sparky_search_exercises"
  "sparky_manage_workout_plans"
  "sparky_manage_checkin"
  "sparky_manage_habits"
  "sparky_manage_goals"
  "sparky_get_goal_snapshot"
  "sparky_get_health_summary"
  "sparky_get_daily_report"
  "sparky_get_report"
  "sparky_get_30_day_trends"
  "sparky_get_contextual_nudge"
  "sparky_get_synced_data"
  "sparky_get_sleep_science"
  "sparky_manage_symptoms"
]
