# lib/cli.sh update
doc="Deadwax CLI - Music metadata extraction.

Usage:
  $(basename "$0") show <type> [options] <id>
  $(basename "$0") search <type> <query>
  $(basename "$0") -h | --help

Arguments:
  show           Show details for a specific resource
  search         Search mode
  type           Resource type (artist(s)|album(s)|song(s)|playlist(s))
  query          Search query
  id             YouTube Music ID (video, playlist, channel) or URL

Options:
  --recommend      Get recommendations based on the ID
                   Can optionally specify a tag: --recommend rock
  -h, --help       Show this screen"

source "${DEADWAX_BASE_DIR}/../lib/core.sh"
source "${DEADWAX_BASE_DIR}/../lib/plugins.sh"

declare -r VALID_TYPES=("album" "artist" "playlist" "song")
declare -r VALID_SEARCH_TYPES=("album" "all" "artist" "playlist" "song")

validate_search_type() {
  local search_type="$1"
  [[ " ${VALID_SEARCH_TYPES[*]} " =~ ${search_type} ]]
}

validate_type() {
  local type="$1"
  [[ " ${VALID_TYPES[*]} " =~ ${type} ]]
}

show_help() {
  echo "$doc"
  exit "${1:-0}"
}

# Parse search-specific arguments
handle_search_request() {
  local -n _search_type=$1
  local -n _target=$2
  shift 2

  if [[ $# -lt 2 ]]; then
    log fatal "Search requires a type and query"
  fi

  _search_type="$1"
  validate_search_type "$_search_type" || {
    log fatal "Invalid search type. Must be one of: ${VALID_SEARCH_TYPES[*]}"
  }

  _target="$2"
}

# Parse show-specific arguments
handle_show_request() {
  local -n _type=$1
  local -n _target=$2
  shift 2

  if [[ $# -lt 2 ]]; then
    log fatal "Show requires a type and ID"
  fi

  _type="$1"
  validate_type "$_type" || {
    log fatal "Invalid type. Must be one of: ${VALID_TYPES[*]}"
  }

  # The target will be set later after parsing options
}

# Parse command options
parse_options() {
  local -n _recommend=$1
  local -n _target=$2
  local is_search="$3"
  shift 3

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --recommend)
      if [[ -n "${2:-}" ]] && [[ "${2:0:1}" != "-" ]]; then
        _recommend="$2"
        shift 2
      else
        _recommend="true"
        shift
      fi
      ;;
    -h | --help)
      show_help
      ;;
    *)
      # Last argument should be the ID/target
      if [[ $# -eq 1 ]]; then
        _target="$1"
        shift
      else
        log fatal "Unknown option: $1"
      fi
      ;;
    esac
  done

  if [[ -z "$_target" ]]; then
    if [[ "$is_search" == "false" ]]; then
      log fatal "No ID provided"
    fi
  fi
}

# Create JSON output
create_json_output() {
  local request="$1"
  local target="$2"
  local recommend="$3"
  local is_search="$4"
  local type="$5"

  local target_json
  if [[ "$is_search" == "true" ]]; then
    target_json=$(jq -n \
      --arg type "$type" \
      --arg value "$target" \
      '{ type: $type, value: $value }')
  else
    target_json=$(jq -n --arg target "$target" '$target')
  fi

  jq -n \
    --arg request "$request" \
    --argjson target "$target_json" \
    --arg recommend "$recommend" '{
        request: $request,
        target: $target,
        options: {
            recommend: (
                if $recommend == "false" then false
                elif $recommend == "true" then true
                else $recommend
                end
            )
        }
    }'
}

process_args() {
  [[ $# -lt 1 ]] && show_help 1

  local REQUEST=""
  local TARGET=""
  local RECOMMEND="false"
  local IS_SEARCH="false"
  local TYPE=""

  case "$1" in
  search)
    IS_SEARCH="true"
    REQUEST="search"
    shift
    handle_search_request TYPE TARGET "$@"
    shift 2
    ;;
  show)
    REQUEST="show"
    shift
    handle_show_request TYPE TARGET "$@"
    shift
    ;;
  -h | --help)
    show_help
    ;;
  *)
    log fatal "Invalid command. Use 'show' or 'search'"
    ;;
  esac

  # Parse remaining options
  parse_options RECOMMEND TARGET "$IS_SEARCH" "$@"

  # For show requests, use the type as the request
  if [[ "$REQUEST" == "show" ]]; then
    REQUEST="$TYPE"
  fi

  # Generate and return JSON output
  create_json_output "$REQUEST" "$TARGET" "$RECOMMEND" "$IS_SEARCH" "$TYPE"
}

cli() {
  local json
  json=$(process_args "$@")
  echo "$json" | pass_to_plugins
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  cli "$@"
fi
