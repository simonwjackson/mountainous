{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;

  cfg = config.mountainous.hyprland;

  # Create a script for adjusting monitor scale
  scaleAdjustScript = pkgs.writeShellScriptBin "adjustScale" ''
    #!${pkgs.bash}/bin/bash
    export PATH="${lib.makeBinPath [pkgs.jq pkgs.hyprland pkgs.gawk]}:$PATH"

    # Parse arguments
    DIRECTION="''${1:-up}"
    TARGET="''${2:-focused}"  # focused, monitor name, or "all"

    # Function to get monitor information based on target
    get_target_monitors() {
      local target="$1"

      if [ "$target" = "all" ] || [ "$target" = "--all" ]; then
        # Return all monitors
        hyprctl --instance 0 monitors -j | jq -r '.[] | "\(.name),\(.width)x\(.height)@\(.refreshRate),\(.x)x\(.y),\(.scale),\(.transform)"'
      elif [ "$target" = "focused" ]; then
        # Return focused monitor
        hyprctl --instance 0 monitors -j | jq -r '.[] | select(.focused == true) | "\(.name),\(.width)x\(.height)@\(.refreshRate),\(.x)x\(.y),\(.scale),\(.transform)"'
      else
        # Return specific monitor by name
        hyprctl --instance 0 monitors -j | jq -r --arg name "$target" '.[] | select(.name == $name) | "\(.name),\(.width)x\(.height)@\(.refreshRate),\(.x)x\(.y),\(.scale),\(.transform)"'
      fi
    }

    # Get monitors based on target
    MONITOR_INFO=$(get_target_monitors "$TARGET")

    if [ -z "$MONITOR_INFO" ]; then
      if [ "$TARGET" = "focused" ]; then
        echo "No focused monitor found"
      elif [ "$TARGET" = "all" ] || [ "$TARGET" = "--all" ]; then
        echo "No monitors found"
      else
        echo "Monitor '$TARGET' not found"
      fi
      exit 1
    fi

    # Function to get valid scales for a resolution
    get_valid_scales() {
      local width=$1
      local height=$2
      local transform=$3

      # Adjust resolution key based on rotation
      local resolution_key
      if [ "$transform" = "1" ] || [ "$transform" = "3" ]; then
        resolution_key="''${height}x''${width}"
      else
        resolution_key="''${width}x''${height}"
      fi

      # Return valid scales based on resolution
      case "$resolution_key" in
        "2024x2560"|"2560x2024")
          echo "0.5 1.0 1.333333 1.6 2.0"
          ;;
        "2880x1800"|"1800x2880")
          echo "1.0 1.125 1.25 1.333333 1.5 1.6 1.8 2.0"
          ;;
        "1920x1080"|"1080x1920")
          echo "0.5 0.75 1.0 1.2 1.25 1.5 2.0"
          ;;
        "3840x2160"|"2160x3840")
          echo "0.5 1.0 1.25 1.5 2.0 2.5 3.0"
          ;;
        "2560x1440"|"1440x2560")
          echo "0.5 1.0 1.25 2.0"
          ;;
        *)
          # Calculate dynamically for unknown resolutions
          local candidate_scales="0.5 0.75 1.0 1.2 1.25 1.333333 1.5 1.6 2.0"
          local valid_scales=""

          for scale in $candidate_scales; do
            if [ "$(awk "BEGIN {print ($width % $scale == 0 && $height % $scale == 0) ? 1 : 0}")" = "1" ]; then
              valid_scales="$valid_scales $scale"
            fi
          done

          # Fallback if no valid scales found
          if [ -z "$valid_scales" ]; then
            echo "0.5 1.0 2.0"
          else
            echo "$valid_scales"
          fi
          ;;
      esac
    }

    # Function to find scale intersection for multiple monitors
    get_scale_intersection() {
      local first=true
      local intersection=""

      while IFS=',' read -r name resolution position scale transform; do
        local width=$(echo "$resolution" | cut -d'x' -f1)
        local height=$(echo "$resolution" | cut -d'x' -f2 | cut -d'@' -f1)
        local monitor_scales=$(get_valid_scales "$width" "$height" "$transform")

        if [ "$first" = true ]; then
          intersection="$monitor_scales"
          first=false
        else
          # Find intersection
          local new_intersection=""
          for scale in $intersection; do
            if echo "$monitor_scales" | grep -q "\b$scale\b"; then
              new_intersection="$new_intersection $scale"
            fi
          done
          intersection="$new_intersection"
        fi
      done <<< "$MONITOR_INFO"

      # Fallback if no intersection
      if [ -z "$intersection" ]; then
        echo "1.0 2.0"
      else
        echo "$intersection"
      fi
    }

    # Function to apply scale to a single monitor
    apply_monitor_scale() {
      local monitor_line="$1"
      local target_scale="$2"
      local all_monitors_info="$3"  # Optional: all monitor info for position recalculation

      local name=$(echo "$monitor_line" | cut -d',' -f1)
      local resolution=$(echo "$monitor_line" | cut -d',' -f2)
      local position=$(echo "$monitor_line" | cut -d',' -f3)
      local current_scale=$(echo "$monitor_line" | cut -d',' -f4)
      local transform=$(echo "$monitor_line" | cut -d',' -f5)

      # Check if we need to recalculate position for eDP-1 in multi-monitor setup
      local new_position="$position"
      if [ -n "$all_monitors_info" ] && [ "$name" = "eDP-1" ]; then
        # Look for DP monitor to calculate relative position
        local dp_monitor=$(echo "$all_monitors_info" | grep -E "^DP-[0-9]")
        if [ -n "$dp_monitor" ]; then
          local dp_resolution=$(echo "$dp_monitor" | cut -d',' -f2)
          local dp_width=$(echo "$dp_resolution" | cut -d'x' -f1)
          local dp_height=$(echo "$dp_resolution" | cut -d'x' -f2 | cut -d'@' -f1)

          # eDP-1 effective width after 270° rotation (2560px physical)
          local edp_width=2560

          # Calculate centered x-position: (DP_width - eDP_width) / (2 * scale)
          local new_x=$(awk "BEGIN {printf \"%.0f\", ($dp_width - $edp_width) / (2 * $target_scale)}")

          # Calculate y-position: DP height / new scale
          local new_y=$(awk "BEGIN {printf \"%.0f\", $dp_height / $target_scale}")

          new_position="''${new_x}x''${new_y}"

          echo "  Recalculating eDP-1 position: $position → $new_position (centered under DP, scale: $target_scale)"
        fi
      fi

      if [ "$target_scale" != "$current_scale" ]; then
        echo "✓ $name: Applying scale $current_scale → $target_scale (transform: $transform)"
        hyprctl --instance 0 keyword monitor "$name,$resolution,$new_position,$target_scale,transform,$transform"

        # Verify the scale was applied
        sleep 0.1
        local actual_scale=$(hyprctl --instance 0 monitors -j | jq -r --arg name "$name" '.[] | select(.name == $name) | .scale')
        local actual_normalized=$(awk "BEGIN {printf \"%.2f\", $actual_scale}")
        local target_normalized=$(awk "BEGIN {printf \"%.2f\", $target_scale}")

        if [ "$actual_normalized" = "$target_normalized" ]; then
          echo "  Scale successfully changed to $target_scale"
        else
          echo "  Warning: Scale change may have failed. Current: $actual_scale, Expected: $target_scale"
        fi
      else
        echo "✓ $name: Scale unchanged ($current_scale)"
      fi
    }

    # Main processing logic
    if [ "$TARGET" = "all" ] || [ "$TARGET" = "--all" ]; then
      # Handle multiple monitors with intersection
      monitor_count=$(echo "$MONITOR_INFO" | wc -l)
      if [ "$monitor_count" -gt 1 ]; then
        echo "Detecting $monitor_count monitors..."
        intersection=$(get_scale_intersection)
        echo "Common scales: [$intersection]"

        # Convert to array
        read -ra VALID_SCALES <<< "$intersection"

        if [ ''${#VALID_SCALES[@]} -le 1 ]; then
          echo "Error: No common scales available for synchronized scaling"
          exit 1
        fi

        # Find the current common scale (or closest)
        # For simplicity, use the first monitor's current scale as reference
        first_monitor=$(echo "$MONITOR_INFO" | head -n1)
        current_scale=$(echo "$first_monitor" | cut -d',' -f4)

        # Find closest scale in intersection
        current_index=0
        min_diff=999
        for i in "''${!VALID_SCALES[@]}"; do
          scale="''${VALID_SCALES[$i]}"
          diff=$(awk "BEGIN {printf \"%.6f\", sqrt(($current_scale - $scale)^2)}")
          is_smaller=$(awk "BEGIN {print ($diff < $min_diff) ? 1 : 0}")
          if [ "$is_smaller" = "1" ]; then
            min_diff=$diff
            current_index=$i
          fi
        done

        # Calculate new index
        if [ "$DIRECTION" = "up" ]; then
          new_index=$((current_index + 1))
          if [ $new_index -ge ''${#VALID_SCALES[@]} ]; then
            new_index=$((''${#VALID_SCALES[@]} - 1))
            echo "Already at maximum common scale"
          fi
        else
          new_index=$((current_index - 1))
          if [ $new_index -lt 0 ]; then
            new_index=0
            echo "Already at minimum common scale"
          fi
        fi

        target_scale="''${VALID_SCALES[$new_index]}"
        echo "Applying scale $target_scale to all monitors:"

        # Apply to all monitors
        while IFS= read -r monitor_line; do
          apply_monitor_scale "$monitor_line" "$target_scale" "$MONITOR_INFO"
        done <<< "$MONITOR_INFO"
      else
        # Single monitor, fall through to individual logic
        TARGET="focused"
      fi
    fi

    # Handle individual monitor (focused or named)
    if [ "$TARGET" != "all" ] && [ "$TARGET" != "--all" ]; then
      # Parse single monitor info
      name=$(echo "$MONITOR_INFO" | cut -d',' -f1)
      resolution=$(echo "$MONITOR_INFO" | cut -d',' -f2)
      position=$(echo "$MONITOR_INFO" | cut -d',' -f3)
      current_scale=$(echo "$MONITOR_INFO" | cut -d',' -f4)
      transform=$(echo "$MONITOR_INFO" | cut -d',' -f5)

      width=$(echo "$resolution" | cut -d'x' -f1)
      height=$(echo "$resolution" | cut -d'x' -f2 | cut -d'@' -f1)

      # Get valid scales for this monitor
      valid_scales_str=$(get_valid_scales "$width" "$height" "$transform")
      read -ra VALID_SCALES <<< "$valid_scales_str"

      # Find current scale index
      current_index=0
      min_diff=999
      for i in "''${!VALID_SCALES[@]}"; do
        scale="''${VALID_SCALES[$i]}"
        diff=$(awk "BEGIN {printf \"%.6f\", sqrt(($current_scale - $scale)^2)}")
        is_smaller=$(awk "BEGIN {print ($diff < $min_diff) ? 1 : 0}")
        if [ "$is_smaller" = "1" ]; then
          min_diff=$diff
          current_index=$i
        fi
      done

      # Calculate new index
      if [ "$DIRECTION" = "up" ]; then
        new_index=$((current_index + 1))
        if [ $new_index -ge ''${#VALID_SCALES[@]} ]; then
          new_index=$((''${#VALID_SCALES[@]} - 1))
          echo "Already at maximum scale"
        fi
      else
        new_index=$((current_index - 1))
        if [ $new_index -lt 0 ]; then
          new_index=0
          echo "Already at minimum scale"
        fi
      fi

      target_scale="''${VALID_SCALES[$new_index]}"
      apply_monitor_scale "$MONITOR_INFO" "$target_scale" ""
    fi
  '';

  # Create a script for toggling between golden ratio and even split
  splitToggleScript = pkgs.writeShellScriptBin "splitToggle" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    export PATH="${lib.makeBinPath [pkgs.jq pkgs.hyprland pkgs.gawk]}:$PATH"

    # Constants
    readonly GOLDEN_RATIO="0.61803"
    readonly EVEN_SPLIT="0.5"
    readonly THRESHOLD="0.559"

    # Global variables
    DEBUG=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
      case $1 in
        -v|--verbose)
          DEBUG=true
          shift
          ;;
        -h|--help)
          echo "Usage: $0 [-v|--verbose] [-h|--help]"
          echo "Toggle between golden ratio and even split layouts"
          exit 0
          ;;
        *)
          echo "Unknown option: $1" >&2
          exit 1
          ;;
      esac
    done

    # Debug logging function
    debug() {
      $DEBUG && echo "[DEBUG] $*" >&2 || true
    }

    # Error function
    error() {
      echo "Error: $*" >&2
      exit 1
    }

    # Get monitor information
    get_monitor_info() {
      local monitor_data
      monitor_data=$(hyprctl --instance 0 monitors -j | jq -r '.[] | select(.focused == true) | "\(.width),\(.scale)"') || error "Failed to get monitor info"

      [ -z "$monitor_data" ] || [ "$monitor_data" = "null," ] && error "No focused monitor found"

      echo "$monitor_data"
    }

    # Get current window layout information
    get_window_layout() {
      local workspace_id orientation windows_info

      workspace_id=$(hyprctl --instance 0 activeworkspace -j | jq -r '.id') || error "Failed to get workspace ID"
      orientation=$(hyprctl --instance 0 getoption master:orientation -j | jq -r '.str') || error "Failed to get orientation"

      # Get windows in current workspace (non-floating only)
      windows_info=$(hyprctl --instance 0 clients -j | jq -r --argjson ws "$workspace_id" '
        [.[] | select(.workspace.id == $ws and .floating == false)] |
        if length == 0 then empty else
          . as $windows |
          (map(.at[0]) | min) as $minx |
          (map(.at[0] + .size[0]) | max) as $maxx |
          {
            windows: (map("\(.size[0]),\(.at[0]),\(.class)") | sort_by(split(",")[1] | tonumber)),
            area_width: ($maxx - $minx),
            orientation: "'"$orientation"'"
          }
        end
      ') || error "Failed to get window layout"

      echo "$windows_info"
    }

    # Determine target ratio based on current state
    determine_target_ratio() {
      local current_ratio="$1"
      local diff_golden diff_even

      diff_golden=$(awk "BEGIN {d=$current_ratio-$GOLDEN_RATIO; printf \"%.5f\", (d<0) ? -d : d}")
      diff_even=$(awk "BEGIN {d=$current_ratio-$EVEN_SPLIT; printf \"%.5f\", (d<0) ? -d : d}")

      if [ "$(awk "BEGIN {print ($diff_golden < $diff_even) ? 1 : 0}")" = "1" ]; then
        debug "Closer to golden ratio (diff: $diff_golden), switching to even split"
        echo "$EVEN_SPLIT"
      else
        debug "Closer to even split (diff: $diff_even), switching to golden ratio"
        echo "$GOLDEN_RATIO"
      fi
    }

    # Apply the new ratio
    apply_ratio() {
      local new_ratio="$1"
      debug "Setting mfact to $new_ratio"
      hyprctl --instance 0 dispatch layoutmsg "mfact exact $new_ratio" || error "Failed to apply ratio"
    }

    # Main execution
    main() {
      local monitor_info physical_width scale logical_width
      local layout_info windows_data area_width orientation
      local master_info master_width actual_ratio new_ratio

      # Get monitor information
      monitor_info=$(get_monitor_info)
      physical_width=$(echo "$monitor_info" | cut -d',' -f1)
      scale=$(echo "$monitor_info" | cut -d',' -f2)
      logical_width=$(awk "BEGIN {printf \"%.0f\", $physical_width / $scale}")

      debug "Monitor: ''${physical_width}px physical, ''${logical_width}px logical (scale $scale)"

      # Get window layout
      layout_info=$(get_window_layout)

      if [ -z "$layout_info" ]; then
        debug "No windows found, using config fallback"
        local current_mfact
        current_mfact=$(hyprctl --instance 0 getoption master:mfact -j | jq -r '.float') || error "Failed to get current mfact"

        if [ "$(awk "BEGIN {print ($current_mfact > $THRESHOLD) ? 1 : 0}")" = "1" ]; then
          new_ratio="$EVEN_SPLIT"
        else
          new_ratio="$GOLDEN_RATIO"
        fi
        debug "Config fallback: switching to $new_ratio"
      else
        # Parse layout information
        orientation=$(echo "$layout_info" | jq -r '.orientation')
        area_width=$(echo "$layout_info" | jq -r '.area_width')

        # Get master window info based on orientation
        if [ "$orientation" = "right" ]; then
          master_info=$(echo "$layout_info" | jq -r '.windows | last')
          debug "Orientation: right (master is rightmost)"
        else
          master_info=$(echo "$layout_info" | jq -r '.windows | first')
          debug "Orientation: left (master is leftmost)"
        fi

        master_width=$(echo "$master_info" | cut -d',' -f1)
        actual_ratio=$(awk "BEGIN {printf \"%.5f\", $master_width / $area_width}")

        debug "Master window: ''${master_width}px logical"
        debug "Window area: ''${area_width}px total"
        debug "Current ratio: $actual_ratio"

        new_ratio=$(determine_target_ratio "$actual_ratio")
      fi

      apply_ratio "$new_ratio"
      $DEBUG || echo "Layout toggled to ratio: $new_ratio"
    }

    main "$@"
  '';
in {
  imports = [
    inputs.hyprland.homeManagerModules.default
  ];

  options.mountainous.hyprland = {
    enable = mkEnableOption "Whether to enable the hyprland desktop";

    # Add new option for custom settings
    extraSettings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional settings to merge with the default configuration";
    };

    # Add option for Hyprland plugins
    plugins = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "List of Hyprland plugins to load";
    };
  };

  config = lib.mkIf cfg.enable {
    # Add scripts to PATH
    home.packages = [
      splitToggleScript
      scaleAdjustScript
    ];

    programs.hyprlock = {
      enable = true;
      settings = {
        general = {
          disable_loading_bar = true;
          grace = 0;
          hide_cursor = true;
          no_fade_in = false;
        };

        background = [
          {
            path = "screenshot";
            blur_passes = 3;
            blur_size = 8;
          }
        ];

        input-field = [
          {
            size = "200, 50";
            position = "0, -80";
            monitor = "";
            dots_center = true;
            fade_on_empty = false;
            font_color = "rgb(202, 211, 245)";
            inner_color = "rgb(91, 96, 120)";
            outer_color = "rgb(24, 25, 38)";
            outline_thickness = 5;
            placeholder_text = ''<span foreground="##cad3f5">Password...</span>'';
            shadow_passes = 2;
          }
        ];
      };
    };

    services.hypridle = {
      enable = false;
      settings = {
        general = {
          after_sleep_cmd = "hyprctl dispatch dpms on";
          ignore_dbus_inhibit = false;
          # lock_cmd = "hyprlock"; # Commented out lock command
        };

        listener = [
          {
            timeout = 300;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
            # on-timeout = "hyprlock & hyprctl dispatch dpms off"; # Commented out locking with screen off
          }
          # {
          #   timeout = 150;
          #   on-timeout = "hyprlock";
          # }
        ];
      };
    };

    wayland.windowManager.hyprland = let
      # curl = "${pkgs.curl}/bin/curl";
      date = "${pkgs.coreutils}/bin/date";
      grep = "${pkgs.gnugrep}/bin/grep";
      # grim = "${pkgs.grim}/bin/grim";
      hyprctl = "${pkgs.hyprland}/bin/hyprctl";
      jq = "${pkgs.jq}/bin/jq";
      playerctl = "${pkgs.playerctl}/bin/playerctl";
      # pngquant = "${pkgs.pngquant}/bin/pngquant";
      # slurp = "${pkgs.slurp}/bin/slurp";
      # swappy = "${pkgs.swappy}/bin/swappy";
      # wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
      wpctl = "${pkgs.wireplumber}/bin/wpctl";
      xargs = "${pkgs.findutils}/bin/xargs";
      firefox = "${pkgs.firefox}/bin/firefox";
      kitty = "${pkgs.kitty}/bin/kitty";
      lf = "${pkgs.lf}/bin/lf";
      walker = "${pkgs.walker}/bin/walker";

      defaultSettings = {
        monitor = [",preferred,auto,auto"];

        "$terminal" = "${kitty}";
        "$fileManager" = "${kitty} -- ${lf}";
        "$mainMod" = "SUPER";
        "$screenshotTmpl" = ''/home/simonwjackson/Pictures/$(${date} +"%Y-%m-%dT%H:%M:%S").png'';

        exec-once = [
          "${pkgs.hyprdim}/bin/hyprdim"
        ];

        env = [
          "XCURSOR_SIZE,24"
          "HYPRCURSOR_SIZE,24"
          "XCURSOR_THEME,catppuccin-frappe-blue-cursors"
          "XCURSOR_SIZE,24"
        ];

        general = {
          gaps_out = 0;
          gaps_in = 5;
          border_size = 0;
          allow_tearing = false;
          layout = "master";
        };

        decoration = {
          rounding = 10;
          active_opacity = 1.0;
          inactive_opacity = 1.0;
          dim_special = 0.8; # Value between 0 and 1, higher = darker

          blur = {
            enabled = true;
            special = true;
            size = 1;
            passes = 2;
            vibrancy = 0.1696;
            new_optimizations = true;
          };

          shadow = {
            enabled = true;
            range = 4;
            render_power = 3;
            color = "rgba(1a1a1aee)";
          };
        };

        animations = {
          enabled = true;

          bezier = [
            "easeOutQuint,0.23,1,0.32,1"
            "easeInOutCubic,0.65,0.05,0.36,1"
            "linear,0,0,1,1"
            "almostLinear,0.5,0.5,0.75,1.0"
            "quick,0.15,0,0.1,1"
          ];

          animation = [
            "global, 1, 10, default"
            "border, 1, 5.39, easeOutQuint"
            "windows, 1, 4.79, easeOutQuint"
            "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
            "windowsOut, 1, 1.49, linear, popin 87%"
            "fadeIn, 1, 1.73, almostLinear"
            "fadeOut, 1, 1.46, almostLinear"
            "fade, 1, 3.03, quick"
            "layers, 1, 3.81, easeOutQuint"
            "layersIn, 1, 4, easeOutQuint, fade"
            "layersOut, 1, 1.5, linear, fade"
            "fadeLayersIn, 1, 1.79, almostLinear"
            "fadeLayersOut, 1, 1.39, almostLinear"
            "workspaces, 1, 1.94, almostLinear, fade"
            "workspacesIn, 1, 1.21, almostLinear, fade"
            "workspacesOut, 1, 1.94, almostLinear, fade"
          ];
        };

        master = {
          orientation = "right";
          mfact = "0.61803";
          new_status = "slave";
          inherit_fullscreen = "false";
        };

        misc = {
          force_default_wallpaper = 0;
          disable_hyprland_logo = true;
          disable_autoreload = false;
          disable_splash_rendering = true;
          background_color = "0x000000";
        };

        input = {
          kb_layout = "us";
          follow_mouse = 1;
          sensitivity = 0;

          touchpad = {
            natural_scroll = false;
          };

          touchdevice = {
            # output = "desc:YHB YHB02P25 0x20240901";
            # transform = 1;
          };
        };

        device = {
          name = "epic-mouse-v1";
          sensitivity = -0.5;
        };

        bind = [
          # Switch workspaces with mainMod + [0-9]
          "$mainMod, 1, workspace, 1"
          "$mainMod, 2, workspace, 2"
          "$mainMod, 3, workspace, 3"
          "$mainMod, 4, workspace, 4"
          "$mainMod, 5, workspace, 5"
          "$mainMod, 6, workspace, 6"
          "$mainMod, 7, workspace, 7"
          "$mainMod, 8, workspace, 8"
          "$mainMod, 9, workspace, 9"
          "$mainMod, 0, workspace, 10"

          #active window to a workspace with mainMod + SHIFT + [0-9]

          "$mainMod SHIFT, 1, movetoworkspace, 1"
          "$mainMod SHIFT, 2, movetoworkspace, 2"
          "$mainMod SHIFT, 3, movetoworkspace, 3"
          "$mainMod SHIFT, 4, movetoworkspace, 4"
          "$mainMod SHIFT, 5, movetoworkspace, 5"
          "$mainMod SHIFT, 6, movetoworkspace, 6"
          "$mainMod SHIFT, 7, movetoworkspace, 7"
          "$mainMod SHIFT, 8, movetoworkspace, 8"
          "$mainMod SHIFT, 9, movetoworkspace, 9"
          "$mainMod SHIFT, 0, movetoworkspace, 10"

          "$mainMod, D, togglespecialworkspace, magic"
          "$mainMod, M, exec, hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.fullscreen' | ${pkgs.gnugrep}/bin/grep -q '2' && ${pkgs.hyprland}/bin/hyprctl dispatch fullscreen 0 || ${pkgs.hyprland}/bin/hyprctl dispatch fullscreen 1"
          # "$mainMod, E, exec, ${kitty} --class tmesh --override 'map ctrl+shift+t pass_keys' --override confirm_os_window_close=0 -- ${lib.getExe inputs.tmesh.packages.${system}.tmesh}"
          "$mainMod SHIFT, E, exec, ${kitty}"
          "$mainMod, A, layoutmsg, swapwithmaster"
          # For Android
          "$mainMod, F1, layoutmsg, swapwithmaster"
          "$mainMod SHIFT, A, exec, ${workspaceCyclerScript}/bin/workspaceCycler"

          "$mainMod, P, exec, ${pkgs.hyprpicker}/bin/hyprpicker -a"
          "$mainMod, W, exec, ${hyprctl} clients | grep -iq 'class: firefox' && ${hyprctl} dispatch focuswindow 'class:^(firefox)$' || ${firefox}"
          "$mainMod, O, exec, ${hyprctl} clients | ${grep} -iq 'class: obsidian' && ${hyprctl} dispatch focuswindow 'class:^(obsidian)$' || ${pkgs.obsidian}/bin/obsidian"
          # "$mainMod, T, exec, ${hyprctl} clients | grep -q 'tmesh' && ${hyprctl} dispatch focuswindow main-term || ${kitty} --class tmesh --override 'map ctrl+shift+t pass_keys' --override confirm_os_window_close=0 -- ${lib.getExe inputs.tmesh.packages.${system}.tmesh}"
          # "$mainMod, G, exec, ${hyprctl} dispatch workspace 2;"
          # "$mainMod SHIFT, G, exec, ${hyprctl} clients | ${grep} -iq 'class: steam' && ${hyprctl} dispatch focuswindow 'class:^(steam)$' || steam"
          "$mainMod, C, killactive,"
          "$mainMod SHIFT, C, exec, ${hyprctl} activewindow -j | ${jq} '.pid' | ${xargs} -r kill -9"
          "$mainMod, F, exec, $fileManager"
          "$mainMod, V, togglefloating,"
          "$mainMod SHIFT, Tab, cyclenext"
          "$mainMod, Tab, cyclenext, -1"
          "$mainMod SHIFT, M, fullscreen, 0"
          "$mainMod, H, movefocus, l"
          "$mainMod, J, movefocus, d"
          "$mainMod, K, movefocus, u"
          "$mainMod, L, movefocus, r"
          "$mainMod, SPACE, exec, ${walker}"
          "$mainMod CTRL, SPACE, exec, ${walker} --modules windows"
          "$mainMod SHIFT, left, resizeactive, -20 0"
          "$mainMod SHIFT, right, resizeactive, 20 0"
          "$mainMod SHIFT, up, resizeactive, 0 -20"
          "$mainMod SHIFT, down, resizeactive, 0 20"
          "$mainMod, left, swapwindow, l"
          "$mainMod, right, swapwindow, r"
          "$mainMod, up, swapwindow, u"
          "$mainMod, down, swapwindow, d"
          "$mainMod, S, exec, pgrep -f 'hyprshot.*ksnip' > /dev/null && pkill -f 'hyprshot.*ksnip' || (${pkgs.hyprshot}/bin/hyprshot --freeze --mode=region --raw | ${pkgs.ksnip}/bin/ksnip -)"
          "$mainMod SHIFT, S, movetoworkspace, special:magic"
          "$mainMod, N, exec, ${pkgs.darkmode-toggle}/bin/darkmode-toggle"
          "$mainMod, equal, exec, ${splitToggleScript}/bin/splitToggle"
        ];

        bindel = [
          ",XF86AudioRaiseVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ",XF86AudioLowerVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ",XF86AudioMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ",XF86AudioMicMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
          ",XF86MonBrightnessUp, exec, ${pkgs.brightness-sync}/bin/brightness-sync up 5"
          ",XF86MonBrightnessDown, exec, ${pkgs.brightness-sync}/bin/brightness-sync down 5"

          # Monitor scaling controls
          "$mainMod SHIFT, plus, exec, ${scaleAdjustScript}/bin/adjustScale up all"
          "$mainMod SHIFT, equal, exec, ${scaleAdjustScript}/bin/adjustScale up all"
          "$mainMod SHIFT, minus, exec, ${scaleAdjustScript}/bin/adjustScale down all"
        ];

        bindl = [
          ", XF86AudioNext, exec, ${playerctl} next"
          ", XF86AudioPause, exec, ${playerctl} play-pause"
          ", XF86AudioPlay, exec, ${playerctl} play-pause"
          ", XF86AudioPrev, exec, ${playerctl} previous"
        ];

        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];

        windowrulev2 = [
          "suppressevent maximize, class:.*"
          "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
          "workspace magic,class:^(steam)$"

          # Firefox specific windows that should float
          "float,class:^(firefox)$,title:^(Library)$"
          "float,class:^(firefox)$,title:^(About Mozilla Firefox)$"
          "float,class:^(firefox)$,title:^(Picture-in-Picture)$"
          "float,class:^(firefox)$,title:^(Firefox — Sharing Indicator)$"
          "float,class:^(firefox)$,title:^(Extension:.*)"

          # Firefox save/open dialogs and popups (they have empty titles)
          "float,class:^(firefox)$,title:^$"
          "center,class:^(firefox)$,floating:1"

          # Explicitly tile the main Firefox window
          "tile,class:^(firefox)$,title:^(.*Mozilla Firefox)$"
          "tile,class:^(firefox)$,title:^(Mozilla Firefox Private Browsing)$"

          # GTK Application dialogs and popups
          "float,title:^(About)(.*)$"
          "float,title:^(Preferences)(.*)$"
          "float,title:^(Settings)(.*)$"
          "float,title:^(Open File)(.*)$"
          "float,title:^(Save File)(.*)$"
          "float,title:^(Save As)(.*)$"
          "float,title:^(Select Folder)(.*)$"
          "float,title:^(Choose)(.*)$"
          "float,title:^(File Chooser)(.*)$"
          "float,title:^(Open Folder)(.*)$"

          # GTK File picker patterns
          "float,class:^(file-roller)$"
          "float,class:^(org.gnome.FileRoller)$"
          "float,title:^(Archive Manager)(.*)$"

          # Common GTK dialog classes
          "float,class:^(zenity)$"
          "float,class:^(yad)$"
          "float,class:^(file-chooser)$"
          "float,class:^(dialog)$"

          # Size constraints for file dialogs
          "size 900 700,title:^(Open File)(.*)$"
          "size 900 700,title:^(Save File)(.*)$"
          "size 900 700,title:^(Save As)(.*)$"
          "size 900 700,title:^(Select Folder)(.*)$"

          # Position Firefox popups in top-right
          "move 100%-20 20,class:^(firefox)$,floating:1"
        ];
      };

      # List of attributes that should be merged instead of replaced
      listAttrs = [
        "exec-once"
        "env"
        "monitor"
        "bind"
        "bindel"
        "bindl"
        "bindm"
        "windowrulev2"
        "animation"
        "bezier"
      ];

      # Function to merge lists for a specific attribute
      mergeListAttr = attr:
        if (defaultSettings ? ${attr} && cfg.extraSettings ? ${attr})
        then {${attr} = (defaultSettings.${attr} or []) ++ (cfg.extraSettings.${attr} or []);}
        else {};

      # Merge all list attributes
      mergedLists = lib.foldl' (acc: attr: acc // (mergeListAttr attr)) {} listAttrs;

      # Final merged settings
      # Use the workspace-cycler package
      workspaceCyclerScript = pkgs.workspace-cycler;

      mergedSettings =
        lib.recursiveUpdate
        (lib.recursiveUpdate defaultSettings cfg.extraSettings)
        mergedLists;
    in {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      plugins = cfg.plugins;
      settings = mergedSettings;
    };
  };
}
