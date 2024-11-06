# Core utility functions

get_script_dir() {
  local source=${BASH_SOURCE[0]}
  local dir

  # Resolve $source until the file is no longer a symlink
  while [ -h "$source" ]; do
    dir="$(cd -P "$(dirname "$source")" && pwd)"
    source="$(readlink "$source")"
    # If $source was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    [[ $source != /* ]] && source="$dir/$source"
  done
  dir="$(cd -P "$(dirname "$source")" && pwd)"
  echo "$dir"
}

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

validate_request() {
  local req="$1"
  case "$req" in
  song | album | artist | playlist | search) return 0 ;;
  *) return 1 ;;
  esac
}

validate_search_type() {
  local type="$1"
  case "$type" in
  artist | album | song | playlist | all) return 0 ;;
  *) return 1 ;;
  esac
}
