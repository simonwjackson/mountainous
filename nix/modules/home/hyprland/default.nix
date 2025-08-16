{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;

  cfg = config.mountainous.hyprland;
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
  };

  config = lib.mkIf cfg.enable {
    programs.hyprlock = {
      enable = false;
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

    services.hyprsunset = {
      enable = true;
      transitions = {
        sunrise = {
          calendar = "*-*-* 06:00:00";
          requests = [
            ["temperature" "6500"]
            ["gamma" "100"]
          ];
        };
        sunset = {
          calendar = "*-*-* 19:00:00";
          requests = [
            ["temperature" "3500"]
          ];
        };
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
      brillo = "${pkgs.brillo}/bin/brillo";
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

        gestures = {
          workspace_swipe = false;
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
          "$mainMod, S, togglespecialworkspace, magic"
          "$mainMod SHIFT, S, movetoworkspace, special:magic"
          "$mainMod, N, exec, ${pkgs.darkmode-toggle}/bin/darkmode-toggle"
        ];

        bindel = [
          ",XF86AudioRaiseVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ",XF86AudioLowerVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ",XF86AudioMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ",XF86AudioMicMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
          ",XF86MonBrightnessUp, exec, sudo ${brillo} -A 5"
          ",XF86MonBrightnessDown, exec, sudo ${brillo} -U 5"
          
          # Monitor scaling controls
          "$mainMod, equal, exec, ${scaleAdjustScript}/bin/adjustScale up"
          "$mainMod, minus, exec, ${scaleAdjustScript}/bin/adjustScale down"
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

      # Create a script for adjusting monitor scale
      scaleAdjustScript = pkgs.writeShellScriptBin "adjustScale" ''
        #!${pkgs.bash}/bin/bash
        export PATH="${lib.makeBinPath [pkgs.jq pkgs.hyprland pkgs.gawk]}:$PATH"

        # Get the direction (up or down)
        DIRECTION="''${1:-up}"

        # Get current monitor configuration
        MONITOR_INFO=$(hyprctl --instance 0 monitors -j | jq -r '.[0] | "\(.name),\(.width)x\(.height)@\(.refreshRate),\(.x)x\(.y),\(.scale)"')
        
        if [ -z "$MONITOR_INFO" ]; then
          echo "Could not get monitor info"
          exit 1
        fi
        
        # Parse monitor info
        MONITOR_NAME=$(echo "$MONITOR_INFO" | cut -d',' -f1)
        RESOLUTION=$(echo "$MONITOR_INFO" | cut -d',' -f2)
        POSITION=$(echo "$MONITOR_INFO" | cut -d',' -f3)
        CURRENT_SCALE=$(echo "$MONITOR_INFO" | cut -d',' -f4)
        
        # Extract resolution width and height
        WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
        HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2 | cut -d'@' -f1)
        
        # Use pre-calculated valid scales for common resolutions to reduce latency
        RESOLUTION_KEY="''${WIDTH}x''${HEIGHT}"
        case "$RESOLUTION_KEY" in
          "2024x2560")
            VALID_SCALES=(0.5 1.0 1.6 2.0)
            ;;
          "1920x1080")
            VALID_SCALES=(0.5 0.75 1.0 1.2 1.25 1.5 2.0)
            ;;
          "3840x2160")
            VALID_SCALES=(0.5 1.0 1.25 1.5 2.0 2.5 3.0)
            ;;
          "2560x1440")
            VALID_SCALES=(0.5 1.0 1.25 2.0)
            ;;
          *)
            # Calculate valid scales dynamically for unknown resolutions
            CANDIDATE_SCALES="0.5 0.75 1.0 1.2 1.25 1.333333 1.5 1.6 2.0"
            VALID_SCALES=()
            
            for scale in $CANDIDATE_SCALES; do
              # Quick integer division check
              sw=$(awk "BEGIN {print int($WIDTH / $scale + 0.5)}")
              sh=$(awk "BEGIN {print int($HEIGHT / $scale + 0.5)}")
              
              # Check if scale produces clean division
              if [ "$(awk "BEGIN {print ($WIDTH % $scale == 0 && $HEIGHT % $scale == 0) ? 1 : 0}")" = "1" ]; then
                VALID_SCALES+=("$scale")
              fi
            done
            
            # Fallback if no valid scales found
            if [ ''${#VALID_SCALES[@]} -eq 0 ]; then
              VALID_SCALES=(0.5 1.0 2.0)
            fi
            ;;
        esac
        
        # Find the index of the current scale or closest scale
        current_index=0
        min_diff=999
        for i in "''${!VALID_SCALES[@]}"; do
          scale="''${VALID_SCALES[$i]}"
          diff=$(awk "BEGIN {printf \"%.6f\", sqrt(($CURRENT_SCALE - $scale)^2)}")
          is_smaller=$(awk "BEGIN {print ($diff < $min_diff) ? 1 : 0}")
          if [ "$is_smaller" = "1" ]; then
            min_diff=$diff
            current_index=$i
          fi
        done
        
        # Calculate new index based on direction
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
        
        # Get the new scale
        NEW_SCALE="''${VALID_SCALES[$new_index]}"
        
        # Apply new scale only if it's different
        if [ "$NEW_SCALE" != "$CURRENT_SCALE" ]; then
          echo "Applying scale: $CURRENT_SCALE -> $NEW_SCALE"
          hyprctl --instance 0 keyword monitor "$MONITOR_NAME,$RESOLUTION,$POSITION,$NEW_SCALE"
          
          # Verify the scale was applied
          sleep 0.1
          ACTUAL_SCALE=$(hyprctl --instance 0 monitors -j | jq -r '.[0].scale')
          if [ "$ACTUAL_SCALE" = "$NEW_SCALE" ]; then
            echo "Scale successfully changed to $NEW_SCALE"
          else
            echo "Warning: Scale change may have failed. Current: $ACTUAL_SCALE, Expected: $NEW_SCALE"
          fi
        else
          echo "Scale unchanged: $CURRENT_SCALE"
        fi
      '';

      mergedSettings =
        lib.recursiveUpdate
        (lib.recursiveUpdate defaultSettings cfg.extraSettings)
        mergedLists;
    in {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      settings = mergedSettings;
    };
  };
}
