# Plugin management functions

get_plugin_dirs() {
  local script_dir
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
  local relative_path="${DEADWAX_BASE_DIR}/../lib/plugins"
  if [[ -d "$relative_path" ]]; then
    plugin_dirs+=("$(cd "$relative_path" && pwd)")
  fi

  # Print all directories, one per line
  printf '%s\n' "${plugin_dirs[@]}"
}

pass_to_plugins() {
  local obj
  local result=""
  local found_plugin=false

  obj="$(cat)"

  # Get all plugin directories
  mapfile -t plugin_dirs < <(get_plugin_dirs)

  # Iterate through each plugin directory
  for plugin_dir in "${plugin_dirs[@]}"; do
    if [[ ! -d "$plugin_dir" ]]; then
      continue
    fi

    # Try each plugin
    for plugin in "$plugin_dir"/*; do
      if [[ -f "$plugin/$(basename "$plugin")" ]]; then
        # Get plugin name
        local plugin_name
        plugin_name="$(basename "$plugin")"

        # Try to execute the plugin with the JSON object
        result=$(echo "$obj" | "$plugin/$plugin_name" 2>/tmp/plugin_error)

        # Check if plugin execution was successful
        if [ $? -eq 0 ]; then
          found_plugin=true
          break 2 # Exit both loops if plugin succeeds
        fi
      fi
    done
  done

  if [[ "$found_plugin" = false ]]; then
    log error "No plugin could handle the request"
    if [ -f /tmp/plugin_error ]; then
      log error "Last plugin error: $(cat /tmp/plugin_error)"
    fi
    return 1
  fi

  echo "$result"
}

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
