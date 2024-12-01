set -euo pipefail

# Configuration defaults
declare -a NAMES=()
declare DURATION=30
declare INTERVAL=5
declare DEBUG=false

# Script description and usage
doc="Process Monitor

    Continuously monitor and find processes by name, killing them if they've been
    running longer than specified duration without subprocesses.

    Usage:
      $(basename "$0") <names...> [options]
      $(basename "$0") -h | --help

    Arguments:
      <names...>              Process names to search for (space-separated)

    Options:
      -d, --duration <seconds> Minimum runtime in seconds (default: 30)
      -i, --interval <seconds> Check interval in seconds (default: 5)
      --debug                  Enable debug mode
      -h, --help              Show this screen."

#
# Logging Functions
#

log() {
  local level="$1"
  shift
  local message="$1"
  shift

  # Skip debug messages unless debug mode is enabled
  if [[ "$level" == "debug" && "$DEBUG" != true ]]; then
    return
  fi

  # Format key-value pairs for structured logging
  local structured=""
  while (("$#")); do
    if [[ $# -eq 1 ]]; then
      break # Skip incomplete pair
    fi
    structured="${structured}[$1=$2] "
    shift 2
  done

  # Prepare the final message with FATAL prefix if needed
  local final_message
  if [[ "$level" == "fatal" ]]; then
    final_message="FATAL: $message $structured"
  else
    final_message="$message $structured"
  fi

  # Execute gum log or fallback to echo on error
  if ! gum log --level="$level" "$final_message"; then
    echo "ERROR: Failed to log message: $final_message" >&2
  fi

  # Exit on fatal errors
  if [[ "$level" == "fatal" ]]; then
    exit 1
  fi
}

#
# Process Management Functions
#

get_process_age() {
  local pid="$1"
  local current_time
  current_time=$(date +%s)
  local start_time
  start_time=$(ps -o lstart= -p "$pid" | date -f - +%s)
  echo $((current_time - start_time))
}

get_child_count() {
  local pid="$1"
  pgrep -P "$pid" | wc -l
}

get_process_name() {
  local pid="$1"
  ps -p "$pid" -o comm= || echo "unknown"
}

find_matching_processes() {
  local name="$1"
  # Find processes matching exact name, excluding vim/nvim editors
  pgrep -x "$name" || true
}

should_terminate_process() {
  local pid="$1"
  local age="$2"
  local child_count="$3"

  if ((age >= DURATION)) && ((child_count == 0)); then
    return 0
  fi
  return 1
}

terminate_process() {
  local pid="$1"
  local name="$2"
  if kill -9 "$pid" 2>/dev/null; then
    log info "Successfully terminated process" name "$name" pid "$pid"
    return 0
  else
    log error "Failed to terminate process" name "$name" pid "$pid"
    return 1
  fi
}

process_exists() {
  local pid="$1"
  kill -0 "$pid" 2>/dev/null
}

#
# Core Process Management Logic
#

check_and_kill_process() {
  local pid="$1"
  local name="$2"
  local process_age
  process_age=$(get_process_age "$pid")
  local child_count
  child_count=$(get_child_count "$pid")

  if should_terminate_process "$pid" "$process_age" "$child_count"; then
    log info "Found process to terminate" name "$name" pid "$pid" age "$process_age" duration "$DURATION"
    terminate_process "$pid" "$name"
    return $?
  fi
  return 1
}

#
# CLI Argument Processing
#

validate_numeric() {
  local value="$1"
  local name="$2"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    log fatal "$name must be a positive integer" "$name" "$value"
  fi
}

process_cli() {
  # Handle help flag if present
  for arg in "$@"; do
    if [[ "$arg" == "-h" ]] || [[ "$arg" == "--help" ]]; then
      echo "$doc"
      exit 0
    fi
  done

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
    -d | --duration)
      DURATION="$2"
      shift 2
      ;;
    -i | --interval)
      INTERVAL="$2"
      shift 2
      ;;
    --debug)
      DEBUG=true
      shift
      ;;
    -*)
      log error "Unknown option '$1'" option "$1"
      echo "$doc"
      exit 1
      ;;
    *)
      NAMES+=("$1")
      shift
      ;;
    esac
  done

  # Require at least one process name
  if [ ${#NAMES[@]} -eq 0 ]; then
    log fatal "At least one process name is required"
  fi

  # Validate numeric arguments
  validate_numeric "$DURATION" "Duration"
  validate_numeric "$INTERVAL" "Interval"

  log debug "Configuration" names "${NAMES[*]}" duration "$DURATION" interval "$INTERVAL" debug "$DEBUG"
}

#
# Main Loop
#

monitor_processes() {
  local names_list
  names_list="${NAMES[*]}"
  log info "Starting continuous process monitor" names "$names_list" duration "$DURATION" interval "$INTERVAL"

  # Track seen PIDs
  declare -A seen_pids

  while true; do
    for name in "${NAMES[@]}"; do
      local pids
      mapfile -t pids < <(find_matching_processes "$name")

      if [ ${#pids[@]} -eq 0 ]; then
        log debug "No processes found matching name" name "$name"
      else
        # Process each PID
        for pid in "${pids[@]}"; do
          # Announce new PIDs
          if [[ -z ${seen_pids[$pid]:-} ]]; then
            log info "Found process" name "$name" pid "$pid"
            seen_pids[$pid]="$name"
          fi

          # Check and possibly terminate the process
          if check_and_kill_process "$pid" "$name"; then
            unset "seen_pids[$pid]"
          fi
        done
      fi
    done

    # Clean up terminated processes
    for pid in "${!seen_pids[@]}"; do
      if ! process_exists "$pid"; then
        unset "seen_pids[$pid]"
      fi
    done

    sleep "$INTERVAL"
  done
}

main() {
  process_cli "$@"

  # Set up trap for clean exit
  trap 'log info "Shutting down process monitor"; exit 0' INT TERM

  monitor_processes
}

main "$@"
