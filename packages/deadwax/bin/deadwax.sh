set -euo pipefail

VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library files
source "${SCRIPT_DIR}/../lib/core.sh"
source "${SCRIPT_DIR}/../lib/plugins.sh"
source "${SCRIPT_DIR}/../lib/formatters.sh"

doc="Deadwax CLI - Music exploration tool.

Usage:
  $(basename "$0") [--format <format>] <request> [options] <id>
  $(basename "$0") [--format <format>] search <type> <query>
  $(basename "$0") -h | --help

  # Also accepts JSON input via stdin:
  echo '{\"request\":\"songs\",\"payload\":\"...\"}' | $(basename "$0")

Arguments:
  request       Type of request (songs|albums|artists|playlists)
  search        Search mode
  type          Type to search for (artist(s)|album(s)|song(s)|playlist(s))
  query         Search query
  id            YouTube Music ID (video, playlist, channel) or URL

Options:
  --format      Output format:
                - For songs: m3u8|xspf|pls|csv|json|jsonl
                - For albums/artists/playlists: csv|json|jsonl
  --recommend   Get recommendations based on the ID
                Can optionally specify a tag: --recommend rock
  -h, --help    Show this screen"

# Initialize variables
REQUEST=""
TARGET=""
RECOMMEND="false"
FORMAT=""
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
  # Normalize the type first
  local normalized_type
  normalized_type=$(normalize_type "$type")

  case "$normalized_type" in
  artist | album | song | playlist) return 0 ;;
  *) return 1 ;;
  esac
}

validate_format() {
  local format="$1"
  local request="$2"

  # Common formats for all types
  local common_formats="csv|json|jsonl"

  case "$request" in
  songs)
    # Songs support additional playlist formats
    if [[ "$format" =~ ^(m3u8|xspf|pls|$common_formats)$ ]]; then
      return 0
    fi
    ;;
  albums | artists | playlists | search)
    # Other types only support common formats
    if [[ "$format" =~ ^($common_formats)$ ]]; then
      return 0
    fi
    ;;
  *)
    return 1
    ;;
  esac

  return 1
}

validate_json() {
  local json="$1"

  # Check if it's valid JSON
  if ! echo "$json" | jq . >/dev/null 2>&1; then
    return 1
  fi

  # Check required fields and structure
  if ! echo "$json" | jq -e 'has("request")' >/dev/null 2>&1; then
    return 1
  fi

  # Validate request type
  local req
  req=$(echo "$json" | jq -r '.request')
  validate_request "$req" || return 1

  # Validate format if present
  if echo "$json" | jq -e 'has("options.format")' >/dev/null 2>&1; then
    local format
    format=$(echo "$json" | jq -r '.options.format')
    validate_format "$format" "$req" || return 1
  fi

  return 0
}

process_json() {
  local json

  json="$(cat)"

  # Validate JSON input
  validate_json "$json" || {
    log fatal "Invalid JSON input. Required format: {\"request\":\"songs|albums|artists|playlists|search\",\"target\":{...},\"options\":{\"format\":\"...\",\"recommend\":\"false|true|string\"}}"
  }

  # Add default options if not present and return both the JSON and format
  local processed_json
  processed_json=$(echo "$json" | jq '
    . * {
      options: (
        .options // {} |
        . * {
          format: (.format // "json"),
          recommend: (.recommend // false)
        }
      )
    }
  ')

  # Extract format from the processed JSON
  local format
  format=$(echo "$processed_json" | jq -r '.options.format')

  echo "$processed_json::$FORMAT"
}

process_args() {
  [[ $# -lt 2 ]] && {
    echo "$doc"
    exit 1
  }

  # Check if this is a search request
  if [[ "$1" == "search" ]]; then
    IS_SEARCH="true"
    REQUEST="search"
    shift

    [[ $# -lt 2 ]] && log fatal "Search requires a type and query"

    SEARCH_TYPE="$1"
    validate_search_type "$SEARCH_TYPE" || {
      log fatal "Invalid search type. Must be one of: artist(s), album(s), song(s), playlist(s)"
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
    --format)
      FORMAT="${2:-jsonl}"
      validate_format "$FORMAT" "$REQUEST" || {
        if [[ "$REQUEST" == "songs" ]]; then
          log fatal "Invalid format for songs. Must be one of: m3u8, xspf, pls, csv, json, jsonl"
        else
          log fatal "Invalid format for $REQUEST. Must be one of: csv, json, jsonl"
        fi
      }
      shift 2
      ;;
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
      --arg format "${FORMAT:-json}" \
      --arg recommend "$RECOMMEND" \
      '{
        request: $request,
        target: {
          type: $type,
          value: $value
        },
        options: {
          format: $format,
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
      --arg format "${FORMAT:-json}" \
      --arg recommend "$RECOMMEND" \
      '{
        request: $request,
        target: $target,
        options: {
          format: $format,
          recommend: (
            if $recommend == "false" then false
            elif $recommend == "true" then true
            else $recommend
            end
          )
        }
      }')
  fi

  echo "$json::$FORMAT"
}

main() {
  local json_and_format

  if [ ! -t 0 ]; then
    json_and_format=$(cat | process_json)
  else
    json_and_format=$(process_args "$@")
  fi

  # Split the result into JSON and format
  local json format
  json="${json_and_format%::*}"
  format="${json_and_format#*::}"

  echo "$json" |
    pass_to_plugins |
    format_output "$format"
}

main "$@"
