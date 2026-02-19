
# Thin wrapper around proseql CLI for task queries
# Usage: task-query [proseql query args...]
#   task-query                                    # all tasks
#   task-query --where 'status = active'          # active only
#   task-query --where 'area = hardware' --json   # hardware tasks as JSON
#   task-query --where 'urgency = high' --select 'id,title'


TASKS_DIR="${TASKS_DIR:-$HOME/tasks}"
PROSEQL_CLI="$HOME/code/github/simonwjackson/proseql/packages/cli/dist/main.js"

cd "$TASKS_DIR"
exec bun "$PROSEQL_CLI" query items "$@"
