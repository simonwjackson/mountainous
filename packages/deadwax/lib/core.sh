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
  if [[ "$level" == "debug" && "${DEBUG:-false}" != true ]]; then
    return
  fi
  gum log --level "$level" "$@"
}
