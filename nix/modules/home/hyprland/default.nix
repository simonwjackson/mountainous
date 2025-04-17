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

    services.hyprsunset = {
      enable = true;
      transitions = {
        sunrise = {
          calendar = "*-*-* 06:00:00";
          requests = [
            [ "temperature" "6500" ]
            [ "gamma" "100" ]
          ];
        };
        sunset = {
          calendar = "*-*-* 19:00:00";
          requests = [
            [ "temperature" "3500" ]
          ];
        };
      };
    };

    services.hypridle = {
      enable = true;
      settings = {
        general = {
          after_sleep_cmd = "hyprctl dispatch dpms on";
          ignore_dbus_inhibit = false;
          lock_cmd = "hyprlock";
        };

        listener = [
          {
            timeout = 180;
            on-timeout = "hyprlock";
          }
          {
            timeout = 120;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
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
      swaybg = "${pkgs.swaybg}/bin/swaybg";
      walker = "${pkgs.walker}/bin/walker";

      defaultSettings = {
        monitor = [",preferred,auto,auto"];

        "$terminal" = "${kitty}";
        "$fileManager" = "${kitty} -- ${lf}";
        "$mainMod" = "SUPER";
        "$screenshotTmpl" = ''/home/simonwjackson/Pictures/$(${date} +"%Y-%m-%dT%H:%M:%S").png'';

        exec-once = [
          "${swaybg} -c '#000000'"
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
          force_default_wallpaper = -1;
          disable_hyprland_logo = true;
          disable_autoreload = false;
          disable_splash_rendering = true;
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
        ];

        bindel = [
          ",XF86AudioRaiseVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ",XF86AudioLowerVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ",XF86AudioMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ",XF86AudioMicMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
          ",XF86MonBrightnessUp, exec, sudo ${brillo} -A 5"
          ",XF86MonBrightnessDown, exec, sudo ${brillo} -U 5"
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
      # Create a script file for workspaceCycler with necessary dependencies
      workspaceCyclerScript = pkgs.writeShellScriptBin "workspaceCycler" ''
        #!${pkgs.bash}/bin/bash
        export PATH="${lib.makeBinPath [pkgs.jq pkgs.hyprland]}:$PATH"
        
        ${builtins.readFile ./workspaceCycle.sh}
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
