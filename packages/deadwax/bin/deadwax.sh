set -euo pipefail

VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library files
source "${SCRIPT_DIR}/../lib/core.sh"
source "${SCRIPT_DIR}/../lib/plugins.sh"

doc="Deadwax CLI - Music exploration tool.

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

# Initialize variables
REQUEST=""
TARGET=""
RECOMMEND="false"
IS_SEARCH="false"
SEARCH_TYPE=""

log() {
  local level="$1"
  shift
  local message="$1"
  shift

  if [[ "$level" == "fatal" ]]; then
    gum log --level "$level" "FATAL: $message"
    exit 1
  else
    gum log --level "$level" "$message"
  fi
}

normalize_type() {
  local type="$1"
  # Remove trailing 's' if present and convert to singular form
  type="${type%s}"
  echo "$type"
}

validate_request() {
  local req="$1"
  case "$req" in
  songs | albums | artists | playlists | search) return 0 ;;
  *) return 1 ;;
  esac
}

validate_search_type() {
  local type="$1"
  local normalized_type
  normalized_type=$(normalize_type "$type")

  case "$normalized_type" in
  artist | album | song | playlist | all) return 0 ;;
  *) return 1 ;;
  esac
}

process_args() {
  [[ $# -lt 1 ]] && {
    echo "$doc"
    exit 1
  }

  # Check if this is a search request
  if [[ "$1" == "search" ]]; then
    IS_SEARCH="true"
    REQUEST="search"
    shift

    if [[ $# -lt 2 ]]; then
      log fatal "Search requires a type and query"
    fi

    SEARCH_TYPE="$1"
    validate_search_type "$SEARCH_TYPE" || {
      log fatal "Invalid search type. Must be one of: artist(s), album(s), song(s), playlist(s), all"
    }

    # Normalize the search type to singular form
    SEARCH_TYPE=$(normalize_type "$SEARCH_TYPE")
    shift

    TARGET="$1"
    shift
  else
    REQUEST="$1"
    shift

    validate_request "$REQUEST" || {
      log fatal "Invalid request type. Must be one of: songs, albums, artists, playlists"
    }
  fi

  # Parse remaining arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --recommend)
      if [[ -n "${2:-}" ]] && [[ "${2:0:1}" != "-" ]]; then
        RECOMMEND="$2"
        shift 2
      else
        RECOMMEND="true"
        shift
      fi
      ;;
    -h | --help)
      echo "$doc"
      exit 0
      ;;
    *)
      # For non-search requests, last argument should be the ID
      if [[ "$IS_SEARCH" == "false" ]]; then
        if [[ $# -eq 1 ]]; then
          TARGET="$1"
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

  # Construct the appropriate JSON based on whether this is a search or regular request
  local json
  if [[ "$IS_SEARCH" == "true" ]]; then
    json=$(jq -n \
      --arg request "$REQUEST" \
      --arg type "$SEARCH_TYPE" \
      --arg value "$TARGET" \
      --arg recommend "$RECOMMEND" \
      '{
        request: $request,
        target: {
          type: $type,
          value: $value
        },
        options: {
          recommend: (
            if $recommend == "false" then false
            elif $recommend == "true" then true
            else $recommend
            end
          )
        }
      }')
  else
    json=$(jq -n \
      --arg request "$REQUEST" \
      --arg target "$TARGET" \
      --arg recommend "$RECOMMEND" '{
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
      }')
  fi

  echo "$json"
}

main() {
  local json

  json=$(process_args "$@")

  echo "$json" |
    pass_to_plugins
}

main "$@"
