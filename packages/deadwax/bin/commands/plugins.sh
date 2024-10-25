#!/usr/bin/env -S nix shell nixpkgs#bash nixpkgs#curl nixpkgs#gnugrep nixpkgs#gum nixpkgs#yt-dlp nixpkgs#mpv -c bash

cmd_plugins_doc="List available plugins

Usage:
  $(basename "$0") plugins [options]

Options:
  --format <format>   Output format (default: text, options: text, json)
"

cmd_plugins() {
  local format="text"
  local subcommand_args=(${CONFIG[subcommand_args]})

  # Process any remaining command-specific args
  while [[ ${#subcommand_args[@]} -gt 0 ]]; do
    case ${subcommand_args[0]} in
    -h | --help)
      echo "$cmd_plugins_doc"
      exit 0
      ;;
    --format)
      format="${subcommand_args[1]}"
      subcommand_args=("${subcommand_args[@]:2}")
      ;;
    *)
      log error "Unexpected argument: ${subcommand_args[0]}"
      echo "$cmd_plugins_doc"
      exit 1
      ;;
    esac
  done

  # Get list of plugins
  local plugins
  readarray -t plugins < <(discover_plugins)

  # Get info for each plugin
  declare -A plugin_info
  for plugin in "${plugins[@]}"; do
    local info
    info=$(execute_plugin_command "$plugin" "info")
    plugin_info[$plugin]=$info
  done

  # Output based on format
  case $format in
  json)
    printf '{\n'
    local first=true
    for plugin in "${plugins[@]}"; do
      if [[ "$first" != true ]]; then
        printf ',\n'
      fi
      printf '  "%s": %s' "$plugin" "${plugin_info[$plugin]}"
      first=false
    done
    printf '\n}\n'
    ;;
  text | *)
    for plugin in "${plugins[@]}"; do
      echo "Plugin: $plugin"
      echo "${plugin_info[$plugin]}" | jq -r '.description'
      echo "Supported commands: $(echo "${plugin_info[$plugin]}" | jq -r '.commands | join(", ")')"
      echo
    done
    ;;
  esac
}
