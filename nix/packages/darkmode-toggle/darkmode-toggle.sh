#!/usr/bin/env bash

# Ultra-fast dark mode toggle script
# Optimized for sub-500ms execution time

set -euo pipefail

# State file to remember current mode
STATE_FILE="$HOME/.config/darkmode-state"

# Get current mode (optimized)
get_current_mode() {
  [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || echo "dark"
}

# Set mode (optimized)
set_mode() {
  echo "$1" >"$STATE_FILE"
}

# Apply theme (unified function)
apply_theme() {
  local mode="$1"

  # Parallel execution of GTK and kitty operations
  {
    # GTK settings via dconf (gsettings uses dconf backend)
    if command -v dconf >/dev/null 2>&1; then
      if [[ "$mode" == "dark" ]]; then
        dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" &
        dconf write /org/gnome/desktop/interface/gtk-theme "'${GTK_DARK_THEME}'" &
      else
        dconf write /org/gnome/desktop/interface/color-scheme "'default'" &
        dconf write /org/gnome/desktop/interface/gtk-theme "'${GTK_LIGHT_THEME}'" &
      fi
    fi

    # Update GTK settings.ini files for xdg-desktop-portal-gtk compatibility
    mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

    if [[ "$mode" == "dark" ]]; then
      # Dark theme settings
      cat >"$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=${GTK_DARK_THEME}
EOF
      cat >"$HOME/.config/gtk-4.0/settings.ini" <<EOF
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=${GTK_DARK_THEME}
EOF
    else
      # Light theme settings
      cat >"$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-application-prefer-dark-theme=0
gtk-theme-name=${GTK_LIGHT_THEME}
EOF
      cat >"$HOME/.config/gtk-4.0/settings.ini" <<EOF
[Settings]
gtk-application-prefer-dark-theme=0
gtk-theme-name=${GTK_LIGHT_THEME}
EOF
    fi
  } &

  {
    # Kitty theme switching (only if kitty exists and themes are available)
    if command -v kitty >/dev/null 2>&1 && [[ -n "${KITTY_THEMES_DIR:-}" ]]; then
      local theme_file config_theme
      if [[ "$mode" == "dark" ]]; then
        theme_file="$KITTY_DARK_THEME"
        config_theme="dark.conf"
      else
        theme_file="$KITTY_LIGHT_THEME"
        config_theme="light.conf"
      fi

      # Fast socket discovery using ss with optimized grep
      local sockets
      sockets=$(ss -lx 2>/dev/null | grep -oE '@mykitty-[0-9]+' | head -3)

      if [[ -n "$sockets" ]]; then
        # Try remote control on running instances
        for socket in $sockets; do
          kitty @ --to "unix:$socket" set-colors --all --configured "$theme_file" 2>/dev/null &
        done
      fi

      # Always set config for new instances (fast path)
      mkdir -p "$HOME/.config/kitty"
      echo "include $HOME/.config/kitty/themes/$config_theme" >"$HOME/.config/kitty/current-theme.conf" &
    fi
  } &

  # Wait for all background operations to complete
  wait

  # Update state
  set_mode "$mode"
}

# Toggle mode (optimized)
toggle_mode() {
  local current_mode
  current_mode=$(get_current_mode)

  if [[ "$current_mode" == "dark" ]]; then
    apply_theme "light"
  else
    apply_theme "dark"
  fi
}

# Main script logic
case "${1:-toggle}" in
  "dark") apply_theme "dark" ;;
  "light") apply_theme "light" ;;
  "toggle") toggle_mode ;;
  "status") echo "Current mode: $(get_current_mode)" ;;
  *)
    echo "Usage: darkmode-toggle [dark|light|toggle|status]"
    exit 1
    ;;
esac
