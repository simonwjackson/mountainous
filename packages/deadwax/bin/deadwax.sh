##!/usr/bin/env -S nix shell nixpkgs#bash nixpkgs#curl nixpkgs#gnugrep nixpkgs#gum nixpkgs#yt-dlp nixpkgs#mpv -c bash

set -euo pipefail

VERSION="0.1.0"

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

get_plugin_dirs() {
  local script_dir
  script_dir="$(get_script_dir)"
  local -A seen_plugins # Associative array to track basenames
  local plugin_dirs=()
  local dir

  # XDG local plugins directory (checked first for overrides)
  local share_path="${XDG_DATA_HOME:-$HOME/.local/share}/deadwax/plugins"
  mkdir -p "$share_path"

  if [[ -d "$share_path" ]]; then
    # Add all local plugin basenames to seen_plugins
    while IFS= read -r plugin; do
      local basename_plugin
      basename_plugin=$(basename "$plugin")
      seen_plugins["$basename_plugin"]=1
    done < <(find "$share_path" -type f -o -type l)
    plugin_dirs+=("$share_path")
  fi

  # Builtin plugins directory (only add if basenames not already seen)
  local relative_path="$script_dir/../lib/plugins"
  if [[ -d "$relative_path" ]]; then
    plugin_dirs+=("$(cd "$relative_path" && pwd)")
  fi

  # Print all directories, one per line
  printf '%s\n' "${plugin_dirs[@]}"
}

# Modified load_plugin function to check all directories
load_plugin() {
  local plugin_name="$1"
  local found=false

  # Validate plugin name contains only alphanumeric chars, dash, and underscore
  if [[ ! "$plugin_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log error "Invalid plugin name: ${plugin_name}"
    return 1
  fi

  # Read plugin directories into an array
  mapfile -t plugin_dirs < <(get_plugin_dirs)

  # Search for plugin in all directories
  for plugin_dir in "${plugin_dirs[@]}"; do
    plugin_dir="$(realpath "${plugin_dir}")"
    local plugin_path="${plugin_dir}/${plugin_name}/${plugin_name}"

    if [[ -f "$plugin_path" && -r "$plugin_path" ]]; then
      # shellcheck source=/dev/null
      if source "$plugin_path"; then
        found=true
        log debug "Loaded plugin ${plugin_name} from ${plugin_dir}"
        break
      else
        log error "Failed to load plugin: ${plugin_name} from ${plugin_dir}"
      fi
    fi
  done

  if [[ "$found" != true ]]; then
    log error "Plugin not found in any directory: ${plugin_name}"
    return 1
  fi

  return 0
}

# Modified list_plugins function to show plugins from all directories
list_plugins() {
  local found_plugins=false
  declare -A seen_plugins

  # Read plugin directories into an array
  mapfile -t plugin_dirs < <(get_plugin_dirs)

  echo "Available plugins:"

  for plugin_dir in "${plugin_dirs[@]}"; do
    if [[ ! -d "$plugin_dir" ]]; then
      continue
    fi

    local dir_has_plugins=false

    for plugin in "$plugin_dir"/*; do
      if [[ -f "$plugin/$(basename "$plugin")" ]]; then
        local plugin_name
        plugin_name="$(basename "$plugin")"

        # Only show each plugin once, with its first occurrence
        if [[ -z "${seen_plugins[$plugin_name]:-}" ]]; then
          echo "  $plugin_name (${plugin_dir})"
          seen_plugins[$plugin_name]=1
          found_plugins=true
          dir_has_plugins=true
        fi
      fi
    done

    if [[ "$dir_has_plugins" == true ]]; then
      echo
    fi
  done

  if [[ "$found_plugins" != true ]]; then
    echo "  No plugins found in any directory"
    echo
    echo "Plugin directories searched:"
    printf "  %s\n" "${plugin_dirs[@]}"
    return 1
  fi
}

doc="YouTube Music Extractor ${VERSION}

Usage:
  deadwax <command> [options] [arguments]
  deadwax plugins [list|update]
  deadwax -h | --help
  deadwax --version

Commands:
  related     Extract music playlists from various sources
  plugins   Manage plugins

Options:
  -h, --help     Show this screen
  --version      Show version
  --debug        Enable debug mode
  --format       Output format (default: m3u8, options: m3u8, jsonl)
  --dry-run      Show what would be done without executing
"

# Utility functions
log() {
  local level="$1"
  shift
  if [[ "$level" == "debug" && "${DEBUG:-false}" != true ]]; then
    return
  fi
  gum log --level "$level" "$@"
}

format_output() {
  local format="$1"
  local json_data

  # Read JSON from stdin
  json_data=$(cat)

  case "$format" in
  m3u8)
    echo "$json_data" | jq -r '
        "#EXTM3U",
        "#PLAYLIST:\(.playlist_name)",
        "#EXTENC:\(.encoding)",
        (.tracks[] |
          "#EXTINF:" + .duration + "," + .artist + " - " + .title,
          "#EXTALB:" + .album,
          "#EXTART:" + .artist,
          "#EXTGENRE:" + .genre,
          "#EXTYEAR:" + .year,
          "#EXTIMG:" + .thumbnail,
          "#YTTITLE:" + .title,
          "#YTID:" + .video_id,
          .url,
          ""
        )
      '
    ;;
  json)
    echo "$json_data" | jq
    ;;
  jsonl)
    echo "$json_data" | jq -c '.tracks[]'
    ;;
  *)
    log error "Unsupported format: $format"
    return 1
    ;;
  esac
}

# Main entrypoint
main() {
  # Default values
  local format="json"
  # local debug=false
  # local dry_run=false

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
    # --debug)
    #   debug=true
    #   shift
    #   ;;
    --format)
      format="$2"
      shift 2
      ;;
    # --dry-run)
    #   dry_run=true
    #   shift
    #   ;;
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
    case "${1:-list}" in
    list)
      list_plugins
      ;;
    update)
      log error "Plugin update not yet implemented"
      exit 1
      ;;
    *)
      log error "Unknown plugins subcommand: $1"
      exit 1
      ;;
    esac
    ;;
  related)
    # Default to ytmusic plugin for related command
    load_plugin "ytmusic"
    related "$@" | format_output "$format"
    ;;
  *)
    # Try to load plugin matching command name
    if load_plugin "$command"; then
      "${command}_main" "$@" | format_output "$format"
    else
      log error "Unknown command: $command"
      echo "$doc"
      exit 1
    fi
    ;;
  esac
}

main "$@"
