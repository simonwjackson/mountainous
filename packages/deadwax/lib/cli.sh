doc="Deadwax CLI - Music metadata extraction.

Usage:
  $(basename "$0") <request> [options] <id>
  $(basename "$0") search <type> <query>
  $(basename "$0") -h | --help

Arguments:
  request       Type of request (songs|albums|artists|playlists)
  search        Search mode
  type          Type to search for (artist(s)|album(s)|song(s)|playlist(s))
  query         Search query
  id            YouTube Music ID (video, playlist, channel) or URL

Options:
  --recommend      Get recommendations based on the ID
                   Can optionally specify a tag: --recommend rock
  -h, --help       Show this screen"

source "${DEADWAX_BASE_DIR}/../lib/core.sh"
source "${DEADWAX_BASE_DIR}/../lib/plugins.sh"

declare -r VALID_REQUESTS=("song" "album" "artist" "playlist")
declare -r VALID_SEARCH_TYPES=("artist" "album" "song" "playlist" "all")

validate_search_type() {
  local search_type="$1"
  [[ " ${VALID_SEARCH_TYPES[*]} " =~ ${search_type} ]]
}

validate_request() {
  local request="$1"
  [[ " ${VALID_REQUESTS[*]} " =~ ${request} ]]
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
      # For non-search requests, last argument should be the ID
      if [[ "$is_search" == "false" ]]; then
        if [[ $# -eq 1 ]]; then
          _target="$1"
          shift
        else
          log fatal "Unknown option: $1"
        fi
      else
        log fatal "Unknown option: $1"
      fi
      ;;
    esac
  done
}

# Create JSON output
create_json_output() {
  local request="$1"
  local target="$2"
  local recommend="$3"
  local is_search="$4"
  local search_type="$5"

  local target_json
  if [[ "$is_search" == "true" ]]; then
    target_json=$(jq -n \
      --arg type "$search_type" \
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
  local SEARCH_TYPE=""

  # Check if this is a search request
  if [[ "$1" == "search" ]]; then
    IS_SEARCH="true"
    REQUEST="search"
    shift
    handle_search_request SEARCH_TYPE TARGET "$@"
    shift 2
  else
    REQUEST="$1"
    shift
    validate_request "$REQUEST" || {
      log fatal "Invalid request type. Must be one of: ${VALID_REQUESTS[*]}"
    }
  fi

  # Parse remaining options
  parse_options RECOMMEND TARGET "$IS_SEARCH" "$@"

  # Generate and return JSON output
  create_json_output "$REQUEST" "$TARGET" "$RECOMMEND" "$IS_SEARCH" "$SEARCH_TYPE"
}

cli() {
  local json
  json=$(process_args "$@")
  echo "$json" | pass_to_plugins
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  cli "$@"
fi
