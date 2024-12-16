{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # An instance of `pkgs` with your overlays and packages applied is also available.
  pkgs,
  # You also have access to your flake's inputs.
  inputs,
  # Additional metadata is provided by Snowfall Lib.
  home, # The home architecture for this host (eg. `x86_64-linux`).
  target, # The Snowfall Lib target for this home (eg. `x86_64-home`).
  format, # A normalized name for the home target (eg. `home`).
  virtual, # A boolean to determine whether this home is a virtual target using nixos-generators.
  host, # The host name for this home.
  # All other arguments come from the home home.
  config,
  ...
}: {
  services.dunst.enable = true;
  mountainous.firefox.enable = true;
  # moun.desktops.hyprland.enable = true;
  # services.udiskie.enable = true;
  # simonwjackson.snowscape.enable = true;

  wayland.windowManager.hyprland = let
    brillo = "${pkgs.brillo}/bin/brillo";
    curl = "${pkgs.curl}/bin/curl";
    date = "${pkgs.coreutils}/bin/date";
    grep = "${pkgs.gnugrep}/bin/grep";
    grim = "${pkgs.grim}/bin/grim";
    hyprctl = "${pkgs.hyprland}/bin/hyprctl";
    jq = "${pkgs.jq}/bin/jq";
    playerctl = "${pkgs.playerctl}/bin/playerctl";
    pngquant = "${pkgs.pngquant}/bin/pngquant";
    slurp = "${pkgs.slurp}/bin/slurp";
    steam = "${pkgs.steam}/bin/steam";
    swappy = "${pkgs.swappy}/bin/swappy";
    wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
    wpctl = "${pkgs.wireplumber}/bin/wpctl";
    xargs = "${pkgs.findutils}/bin/xargs";
  in {
    enable = true;

    # Source additional configuration file
    extraConfig = let
      configDir = config.xdg.configHome;
    in ''
      # source = ${configDir}/hypr/extra-config.conf
    '';

    settings =
      lib.recursiveUpdate {
        monitor = [",preferred,auto,auto"];

        "$terminal" = "kitty";
        "$fileManager" = "dolphin";
        "$menu" = "wofi --show drun";
        "$mainMod" = "SUPER";
        "$screenshotTmpl" = ''/home/simonwjackson/Pictures/$(${date} +"%Y-%m-%dT%H:%M:%S").png'';

        env = [
          "XCURSOR_SIZE,24"
          "HYPRCURSOR_SIZE,24"
        ];

        general = {
          gaps_in = 5;
          border_size = 0;
          allow_tearing = false;
          layout = "master";
        };

        decoration = {
          rounding = 10;
          active_opacity = 1.0;
          inactive_opacity = 1.0;

          blur = {
            enabled = true;
            size = 3;
            passes = 1;
            vibrancy = 0.1696;
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

        dwindle = {
          pseudotile = true;
          preserve_split = true;
        };

        master = {
          new_status = "master";
        };

        misc = {
          force_default_wallpaper = -1;
          disable_hyprland_logo = false;
        };

        input = {
          kb_layout = "us";
          follow_mouse = 1;
          sensitivity = 0;

          touchpad = {
            natural_scroll = false;
          };
        };

        gestures = {
          workspace_swipe = false;
        };

        device = {
          name = "epic-mouse-v1";
          sensitivity = -0.5;
        };

        "$resetSubmap" = "${hyprctl} dispatch submap reset";
        "$getWindow" = ''$resetSubmap; ${hyprctl} activewindow -j | ${jq} -r ". | \"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])\"" | ${xargs} -I '%' ${grim} -g '%' -'';
        "$getMonitor" = "$resetSubmap; ${hyprctl} monitors -j | ${jq} -r '.[] | select(.focused==true) | .name' | ${xargs} -I '%' ${grim} -o '%' -";
        "$getRegion" = "$resetSubmap; ${grim} -g \"$(${slurp})\" -";
        "$compressThenSave" = "${pngquant} - > $screenshotTmpl";
        "$publishToInternet" = "${curl} -s -F'file=@-' https://0x0.st | tee >(${wl-copy})";
        "$markup" = "${swappy} -f - -o -";

        /*
        # Hyprland Screenshot Key Combinations

        ## Full Key Combination Table

        | Base Combo        | Next Key | Final Key | Description |
        |-------------------|----------|-----------|-------------|
        | Super + S         |    W     |    F      | Save window screenshot with compression |
        | Super + S         |          |    C      | Copy window screenshot to clipboard |
        | Super + S         |          |    I      | Upload window screenshot to 0x0.st and copy URL |
        | Super + S         |    M     |    F      | Save monitor/screen screenshot with compression |
        | Super + S         |          |    C      | Copy monitor/screen screenshot to clipboard |
        | Super + S         |          |    I      | Upload monitor/screen screenshot to 0x0.st and copy URL |
        | Super + S         |    R     |    F      | Save region/selection screenshot with compression |
        | Super + S         |          |    C      | Copy region/selection screenshot to clipboard |
        | Super + S         |          |    I      | Upload region/selection screenshot to 0x0.st and copy URL |
        | Super + Shift + S |    W     |    F      | Save window screenshot with markup/editing and compression |
        | Super + Shift + S |          |    C      | Copy window screenshot with markup/editing to clipboard |
        | Super + Shift + S |          |    I      | Upload window screenshot with markup/editing to 0x0.st and copy URL |
        | Super + Shift + S |    M     |    F      | Save monitor screenshot with markup/editing and compression |
        | Super + Shift + S |          |    C      | Copy monitor screenshot with markup/editing to clipboard |
        | Super + Shift + S |          |    I      | Upload monitor screenshot with markup/editing to 0x0.st and copy URL |
        | Super + Shift + S |    R     |    F      | Save region screenshot with markup/editing and compression |
        | Super + Shift + S |          |    C      | Copy region screenshot with markup/editing to clipboard |
        | Super + Shift + S |          |    I      | Upload region screenshot with markup/editing to 0x0.st and copy URL |

        ## Quick Reference

        ### First Key (W/M/R)
        - **W** = Window (current active window)
        - **M** = Monitor (full screen)
        - **R** = Region (select area)

        ### Final Key (F/C/I)
        - **F** = File (save to disk)
        - **C** = Copy to clipboard
        - **I** = Upload to Internet (0x0.st)

        ### Notes
        - Press Escape at any time to cancel the screenshot operation
        - Adding Shift to the base combo (Super + Shift + S) enables markup/editing mode
        - All saved files are automatically compressed using pngquant
        - Internet uploads automatically copy the URL to your clipboard
        */

        # Screenshot submaps and their bindings
        # submap = {
        #   screenshot = {
        #     bind = [
        #       ", W, submap, screenshot-window"
        #       ", M, submap, screenshot-monitor"
        #       ", R, submap, screenshot-region"
        #       ", escape, submap, reset"
        #       ", _, submap, reset"
        #     ];
        #   };
        #
        #   "screenshot-window" = {
        #     bind = [
        #       ", F, exec, $getWindow | $compressThenSave"
        #       ", C, exec, $getWindow | ${wl-copy}"
        #       ", I, exec, $getWindow | $publishToInternet"
        #       ", escape, submap, reset"
        #       ", _, submap, reset"
        #     ];
        #   };
        #
        #   "screenshot-monitor" = {
        #     bind = [
        #       ", F, exec, $getMonitor | $compressThenSave"
        #       ", C, exec, $getMonitor | ${wl-copy}"
        #       ", I, exec, $getMonitor | $publishToInternet"
        #       ", escape, submap, reset"
        #       ", _, submap, reset"
        #     ];
        #   };
        #
        #   "screenshot-region" = {
        #     bind = [
        #       ", F, exec, $getRegion | $compressThenSave"
        #       ", C, exec, $getRegion | ${wl-copy}"
        #       ", I, exec, $getRegion | $publishToInternet"
        #       ", escape, submap, reset"
        #       ", _, submap, reset"
        #     ];
        #   };
        #
        #   "screenshot-markup" = {
        #     bind = [
        #       ", W, submap, screenshot-markup-window"
        #       ", M, submap, screenshot-markup-monitor"
        #       ", R, submap, screenshot-markup-region"
        #       ", escape, submap, reset"
        #       ", _, submap, reset"
        #     ];
        #   };
        #
        #   "screenshot-markup-window" = {
        #     bind = [
        #       ", F, exec, $getWindow | $markup | $compressThenSave"
        #       ", C, exec, $getWindow | $markup | ${wl-copy}"
        #       ", I, exec, $getWindow | $markup | $publishToInternet"
        #       ", escape, submap, reset"
        #       ", _, submap, reset"
        #     ];
        #   };
        #
        #   "screenshot-markup-monitor" = {
        #     bind = [
        #       ", F, exec, $getMonitor | $markup | $compressThenSave"
        #       ", C, exec, $getMonitor | $markup | ${wl-copy}"
        #       ", I, exec, $getMonitor | $markup | $publishToInternet"
        #       ", escape, submap, reset"
        #       ", _, submap, reset"
        #     ];
        #   };
        #
        #   "screenshot-markup-region" = {
        #     bind = [
        #       ", F, exec, $getRegion | $markup | $compressThenSave"
        #       ", C, exec, $getRegion | $markup | ${wl-copy}"
        #       ", I, exec, $getRegion | $markup | $publishToInternet"
        #       ", escape, submap, reset"
        #       ", _, submap, reset"
        #     ];
        #   };
        #
        #   reset = {};
        # };

        # Keybindings
        bind = [
          "$mainMod, E, exec, kitty"
          "$mainMod, A, layoutmsg, swapwithmaster"
          "$mainMod, W, exec, ${hyprctl} clients | grep -q 'firefox' && ${hyprctl} dispatch focuswindow firefox || ${pkgs.firefox}"
          "$mainMod, T, exec, ${hyprctl} clients | grep -q 'main-term' && ${hyprctl} dispatch focuswindow main-term || $mainTerm"
          "$mainMod, G, exec, ${hyprctl} dispatch workspace 2;"
          "$mainMod SHIFT, G, exec, ${hyprctl} clients | ${grep} -q 'steam' && ${hyprctl} dispatch focuswindow steam || ${steam}"

          "$mainMod, C, killactive,"
          "$mainMod SHIFT, C, exec, ${hyprctl} activewindow -j | ${jq} '.pid' | ${xargs} -r kill -9"
          "$mainMod, F, exec, $fileManager"
          "$mainMod, V, togglefloating,"
          "$mainMod SHIFT, Tab, cyclenext"
          "$mainMod, Tab, cyclenext, -1"
          "$mainMod SHIFT, M, fullscreen, 0"

          # Focus movement
          "$mainMod, H, movefocus, l"
          "$mainMod, J, movefocus, d"
          "$mainMod, K, movefocus, u"
          "$mainMod, L, movefocus, r"

          "$mainMod SHIFT, left, resizeactive, -20 0"
          "$mainMod SHIFT, right, resizeactive, 20 0"
          "$mainMod SHIFT, up, resizeactive, 0 -20  "
          "$mainMod SHIFT, down, resizeactive, 0 20 "

          "$mainMod, left, swapwindow, l"
          "$mainMod, right, swapwindow, r"
          "$mainMod, up, swapwindow, u"
          "$mainMod, down, swapwindow, d"

          # Special workspace
          "$mainMod, S, togglespecialworkspace, magic"
          "$mainMod SHIFT, S, movetoworkspace, special:magic"
        ];

        # Binding elements (for media keys)
        bindel = [
          ",XF86AudioRaiseVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ",XF86AudioLowerVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ",XF86AudioMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ",XF86AudioMicMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
          ",XF86MonBrightnessUp, exec, sudo ${brillo} -A 5"
          ",XF86MonBrightnessDown, exec, sudo ${brillo} -U 5"
        ];

        # Binding with latches (for media control)
        bindl = [
          ", XF86AudioNext, exec, ${playerctl} next"
          ", XF86AudioPause, exec, ${playerctl} play-pause"
          ", XF86AudioPlay, exec, ${playerctl} play-pause"
          ", XF86AudioPrev, exec, ${playerctl} previous"
        ];

        # Mouse bindings
        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];

        # Window rules
        windowrulev2 = [
          "suppressevent maximize, class:.*"
          "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
        ];
      } {
        general = {
          gaps_out = 0;
        };
      };
  };

  home = {
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "24.11"; # WARN: Changing this might break things. Just leave it.
  };
}
