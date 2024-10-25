##!/usr/bin/env -S nix shell nixpkgs#bash nixpkgs#curl nixpkgs#gnugrep nixpkgs#gum nixpkgs#yt-dlp nixpkgs#mpv -c bash

cmd_radio_doc="Generate radio playlists from songs, albums, or artists

Usage:
  $(basename "$0") radio [options] <url|id>

Options:
  --format <format>     Output format (default: m3u8, options: m3u8, jsonl)
  --dry-run            Show what the script would do without executing
  --tag <tag>          Specify a tag for song or album playlists
  --sources <sources>  Comma-separated list of sources to use (default: all)
"

cmd_radio() {
  local input=""
  local subcommand_args=(${CONFIG[subcommand_args]})

  # Process any remaining command-specific args
  while [[ ${#subcommand_args[@]} -gt 0 ]]; do
    case ${subcommand_args[0]} in
    -h | --help)
      echo "$cmd_radio_doc"
      exit 0
      ;;
    *)
      if [[ -z "$input" ]]; then
        input="${subcommand_args[0]}"
      else
        log error "Unexpected argument: ${subcommand_args[0]}"
        echo "$cmd_radio_doc"
        exit 1
      fi
      ;;
    esac
    subcommand_args=("${subcommand_args[@]:1}")
  done

  if [[ -z "$input" ]]; then
    log error "Missing input URL or ID"
    echo "$cmd_radio_doc"
    exit 1
  fi

  if [[ "${CONFIG[dry_run]}" == true ]]; then
    log info "Dry run mode: Showing what would be done without executing"
    echo "Input: $input"
    echo "Format: ${CONFIG[format]}"
    echo "Debug mode: ${CONFIG[debug]}"
    echo "Tag: ${CONFIG[tag]}"
    exit 0
  fi

  # Get list of plugins to execute
  local plugins
  if [[ -n "${CONFIG[sources]}" ]]; then
    IFS=',' read -ra plugins <<<"${CONFIG[sources]}"
  else
    readarray -t plugins < <(discover_plugins)
  fi

  # Execute each plugin
  local results=()
  for plugin in "${plugins[@]}"; do
    if [[ "${CONFIG[debug]}" == true ]]; then
      log debug "Executing plugin: $plugin"
    fi

    # Execute plugin with all relevant config options
    local plugin_result
    plugin_result=$(
      execute_plugin_command "$plugin" "radio" \
        --format "${CONFIG[format]}" \
        --tag "${CONFIG[tag]}" \
        "$input"
    )

    if [[ $? -eq 0 ]]; then
      results+=("$plugin_result")
    fi
  done

  # Output results based on format
  if [[ "${#results[@]}" -eq 0 ]]; then
    log error "No results found"
    exit 1
  fi

  # For now, just output the first result since we only have one plugin
  echo "${results[0]}"
}
