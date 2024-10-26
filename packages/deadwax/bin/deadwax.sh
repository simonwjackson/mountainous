set -euo pipefail

VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library files
source "${SCRIPT_DIR}/../lib/core.sh"
source "${SCRIPT_DIR}/../lib/plugins.sh"
source "${SCRIPT_DIR}/../lib/formatters.sh"

doc="deadwax ${VERSION}

Usage:
  deadwax <command> [options] [arguments]
  deadwax plugins [list|update]
  deadwax -h | --help
  deadwax --version

Commands:
  direct        Extract direct content from a URL
  related       Extract music playlists from various sources
  plugins       Manage plugins

Options:
  -h, --help   Show this screen
  --version    Show version
  --debug      Enable debug mode
  --format     Output format (default: m3u8, options: m3u8, jsonl)
"

main() {
  # Default values
  local format="jsonl"

  # Parse global options
  while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help)
      echo "$doc"
      exit 0
      ;;
    --version)
      echo "ytme version ${VERSION}"
      exit 0
      ;;
    --format)
      format="$2"
      shift 2
      ;;
    *)
      break
      ;;
    esac
  done

  # Require a command
  if [[ $# -eq 0 ]]; then
    log error "Missing command"
    echo "$doc"
    exit 1
  fi

  local command="$1"
  shift

  case "$command" in
  plugins)
    list_plugins
    ;;
  direct)
    local url="${!#}"
    if [[ -z "$url" ]]; then
      log error "Missing URL for direct command"
      exit 1
    fi

    # Parse optional arguments
    local -A args=()
    while [[ $# -gt 1 ]]; do
      case "$1" in
      --tag)
        args["tag"]="$2"
        shift 2
        ;;
      *)
        shift
        ;;
      esac
    done

    # Build the JSON object for plugins
    local json_obj
    json_obj=$(jq -n \
      --arg cmd "direct" \
      --arg url "$url" \
      --arg tag "${args[tag]:-all}" \
      '{
        command: $cmd,
        id: $url,
        args: {
          tag: $tag
        }
      }')

    # Pass to plugins and format output
    pass_to_plugins "$json_obj" |
      format_output "$format"
    ;;
  related)
    local url="${!#}"
    if [[ -z "$url" ]]; then
      log error "Missing URL for related command"
      exit 1
    fi

    # Parse optional arguments
    local -A args=()
    while [[ $# -gt 1 ]]; do
      case "$1" in
      --tag)
        args["tag"]="$2"
        shift 2
        ;;
      *)
        shift
        ;;
      esac
    done

    # Build the JSON object for plugins
    local json_obj
    json_obj=$(jq -n \
      --arg cmd "related" \
      --arg url "$url" \
      --arg tag "${args[tag]:-all}" \
      '{
        command: $cmd,
        id: $url,
        args: {
          tag: $tag
        }
      }')

    # Pass to plugins and format output
    pass_to_plugins "$json_obj" | format_output "$format"
    ;;
  *)
    log error "Unknown command: $command"
    echo "$doc"
    exit 1
    ;;
  esac
}

main "$@"
