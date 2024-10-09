{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}: let
  inherit (lib) mkIf mkEnableOption mkOpt;

  tmesh = lib.getExe inputs.tmesh.packages.${system}.default;
  cfg = config.backpacker.desktops.hyprland;
in {
  imports = [
    inputs.hyprland.homeManagerModules.default
  ];
  # ++ lib.snowfall.fs.get-non-default-nix-files ./.;

  options.backpacker.desktops.hyprland = {
    enable = mkEnableOption "enable hyprland window manager";

    autoLogin = lib.mkEnableOption "Whether to auto login to the plasma desktop";
  };

  # FIX: this hack to use nix catppuccin module: https://github.com/catppuccin/nix/issues/102
  # options.wayland.windowManager.hyprland = {
  #   settings = mkEnableOption "enable hyprland window manager";
  # };

  config = lib.mkIf cfg.enable {
    # nix.settings = {
    #   trusted-substituters = lib.mkAfter [
    #   ];
    #   trusted-public-keys = lib.mkAfter [
    #   ];
    # };

    # wayland.windowManager.hyprland.systemd.variables = ["-all"];

    wayland.windowManager.hyprland = {
      enable = true;
      extraConfig = ''
        source=b.conf
      '';

      settings = {
        # https://wiki.hyprland.org/Configuring/Variables/#misc

        misc = {
          # Set to 0 or 1 to disable the anime mascot wallpapers
          force_default_wallpaper = 0;
          # If true disables the random hyprland logo / anime girl background. :(
          disable_hyprland_logo = true;
        };

        monitor = [
          # Recommended rule for quickly plugging in random monitors
          ",preferred,auto,1"
        ];

        ###################
        ### MY PROGRAMS ###
        ###################

        # See https://wiki.hyprland.org/Configuring/Keywords/

        "$terminal" = "$TERMINAL";
        "$mainTerm" = "$terminal --class main-term tmesh";
        "$fileManager" = "$terminal -- lf";
        "$mod" = "SUPER";

        #################
        ### AUTOSTART ###
        #################

        exec-once = [
          (lib.getExe pkgs.firefox)
        ];

        #####################
        ### LOOK AND FEEL ###
        #####################

        # Refer to https://wiki.hyprland.org/Configuring/Variables/
        # https://wiki.hyprland.org/Configuring/Variables/#general

        general = {
          gaps_in = 10;
          gaps_out = 0;

          border_size = 0;

          # Set to true enable resizing windows by clicking and dragging on borders and gaps
          resize_on_border = false;

          # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
          allow_tearing = false;

          layout = "master";
        };

        # https://wiki.hyprland.org/Configuring/Variables/#decoration
        decoration = {
          rounding = 5;

          # Change transparency of focused and unfocused windows
          active_opacity = 1;
          inactive_opacity = 1;

          drop_shadow = true;
          shadow_range = 4;
          shadow_render_power = 3;
          "col.shadow" = "rgba(1a1a1aee)";

          # https://wiki.hyprland.org/Configuring/Variables/#blur
          blur = {
            enabled = true;
            size = 3;
            passes = 1;

            vibrancy = 0.1696;
          };
        };

        # https://wiki.hyprland.org/Configuring/Variables/#animations
        animations = {
          enabled = true;

          # Default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more

          bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";

          animation = [
            "windows, 1, 7, myBezier"
            "windowsOut, 1, 7, default, popin 80%"
            "border, 1, 10, default"
            "borderangle, 1, 8, default"
            "fade, 1, 7, default"
            "workspaces, 1, 6, default"
          ];
        };

        # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
        dwindle = {
          pseudotile = true; # Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
          preserve_split = true; # You probably want this
        };

        # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
        master = {
          new_is_master = false;
          mfact = 0.66;
          orientation = "right";
          new_on_top = 0;
        };

        #############################
        ### ENVIRONMENT VARIABLES ###
        #############################

        # See https://wiki.hyprland.org/Configuring/Environment-variables/

        env = [
          "XCURSOR_SIZE,24"
          "HYPRCURSOR_SIZE,24"
        ];

        #############
        ### INPUT ###
        #############

        # https://wiki.hyprland.org/Configuring/Variables/#input
        input = {
          kb_layout = "us";
          kb_variant = "";
          kb_model = "";
          kb_options = "";
          kb_rules = "";

          follow_mouse = 1;

          sensitivity = 0; # -1.0 - 1.0, 0 means no modification.

          touchpad = {
            natural_scroll = false;
          };
        };

        # https://wiki.hyprland.org/Configuring/Variables/#gestures
        gestures = {
          workspace_swipe = false;
        };

        # Example per-device config
        # See https://wiki.hyprland.org/Configuring/Keywords/#per-device-input-configs for more
        device = {
          name = "epic-mouse-v1";
          sensitivity = "-0.5";
        };

        ####################
        ### KEYBINDINGSS ###
        ####################

        # See https://wiki.hyprland.org/Configuring/Keywords/
        "$mainMod" = "SUPER"; # Sets "Windows" key as main modifier

        # Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
        bind = [
          "$mainMod, A, layoutmsg, swapwithmaster"
          "$mainMod, W, exec, hyprctl clients | grep -q 'firefox' && hyprctl dispatch focuswindow firefox || firefox"
          "$mainMod, T, exec, hyprctl clients | grep -q 'main-term' && hyprctl dispatch focuswindow main-term || $mainTerm"
          "$mainMod, G, exec, hyprctl dispatch workspace 10; hyprctl clients | grep -q 'steam' && hyprctl dispatch focuswindow steam || flatpak run com.valvesoftware.Steam"
          "$mainMod, C, killactive,"
          "$mainMod, F, exec, $fileManager"
          "$mainMod, V, togglefloating,"
          "$mainMod, R, exec, $menu"
          # bind = $mainMod, P, pseudo, # dwindle
          "$mainMod SHIFT, Tab, cyclenext"
          "$mainMod, Tab, cyclenext, -1"
          #$mainMod, P, togglesplit #, dwindle
          "$mainMod, M, fullscreen, 1"
          # Toggle pseudo-fullscreen mode for the focused window
          "$mainMod SHIFT, M, fullscreen, 0"
          # Move focus with mainMod + arrow keys
          "$mainMod, H, movefocus, l"
          "$mainMod, J, movefocus, d"
          "$mainMod, K, movefocus, u"
          "$mainMod, L, movefocus, r"

          "$mainMod SHIFT, left, resizeactive, -20 0"
          "$mainMod SHIFT, right, resizeactive, 20 0"
          "$mainMod SHIFT, up, resizeactive, 0 -20"
          "$mainMod SHIFT, down, resizeactive, 0 20"

          "$mainMod, left, swapwindow, l"
          "$mainMod, right, swapwindow, r"
          "$mainMod, up, swapwindow, u"
          "$mainMod, down, swapwindow, d"

          ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ", XF86MonBrightnessUp, exec, sudo ddcutil setvcp 10 + 5"
          ", XF86MonBrightnessDown, exec, sudo ddcutil setvcp 10 - 5"

          # Example special workspace (scratchpad)
          "$mainMod, S, togglespecialworkspace, magic"
          "$mainMod SHIFT, S, movetoworkspace, special:magic"
        ];

        windowrule = [
          "tile,^(kitty)$"
        ];

        windowrulev2 = [
          "tag +steam, class:(steam)"

          # You'll probably like this.
          "suppressevent maximize, class:.*"

          "float,class:^(kitty)$,title:^(kitty)$"
        ];

        bindm = [
          # Move/resize windows with mainMod + LMB/RMB and dragging
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];

        #   windowrule = [
        #     "tile,^(kitty)$"
        #   ];
        #   animation = [
        #     "workspaces,1,8,default"
        #     "windows,0"
        #     "fade,0"
        #   ];
        #   monitor = [
        #     "DP-1,2560x1440@360,0x0,1"
        #     "DP-1,addreserved,50,50,400,400"
        #     "DP-2,2560x1440@360,0x0,1"
        #     "DP-2,addreserved,50,50,400,400"
        #     "DP-3,2560x1440@360,0x0,1"
        #     "DP-3,addreserved,50,50,400,400"
        #     "DP-4,2560x1440@360,0x0,1"
        #     "DP-4,addreserved,50,50,400,400"
        #   ];
        #   bindm = [
        #     "$mod, mouse:272, moveactive"
        #     "$mod, mouse:273, resizewindow"
        #   ];
        #   bind =
        #     [
        #       # Focus windows
        #       "$mod, h, movefocus, l"
        #       "$mod, j, movefocus, d"
        #       "$mod, k, movefocus, u"
        #       "$mod, l, movefocus, r"
        #
        #       # Apps
        #       "$mod, w, exec, firefox-esr"
        #       # "$mod, p, exec, ${pkgs.procps}/bin/pgrep -f 'main-term' > /dev/null || ${lib.getExe pkgs.kitty} --class main-term ${tmesh}"
        #       "$mod, t, exec, ${lib.getExe pkgs.kitty}"
        #
        #       # Toggle monocle mode for the focused window
        #       "$mod, m, fullscreen, 1"
        #
        #       # Toggle pseudo-fullscreen mode for the focused window
        #       "$mod_SHIFT, f, fullscreen, 0"
        #
        #       # Cycle through windows
        #       "$mod, Tab, cyclenext"
        #       "$mod_SHIFT, Tab, cyclenext, prev"
        #
        #       # Cycle through windows in all workspaces
        #       "$mod_ALT_CTRL, Tab, cyclenext, allworkspaces"
        #       "$mod_ALT_CTRL_SHIFT, Tab, cyclenext, prev, allworkspaces"
        #     ]
        #     ++ (
        #       # workspaces
        #       # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
        #       builtins.concatLists (builtins.genList (
        #           x: let
        #             ws = let
        #               c = (x + 1) / 10;
        #             in
        #               builtins.toString (x + 1 - (c * 10));
        #           in [
        #             "$mod, ${ws}, workspace, ${toString (x + 1)}"
        #             "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
        #           ]
        #         )
        #         10)
        #     );
      };
    };

    # xdg.configFile."hypr".recursive = true;
  };
}
