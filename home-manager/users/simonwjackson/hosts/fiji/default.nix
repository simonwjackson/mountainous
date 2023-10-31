{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    inputs.nix-colors.homeManagerModules.default
    ../../global
    ./aria2.nix
    ./beets.nix
    ./firefox
    ./kitty
  ];

  gtk = {
    enable = true;
    # iconTheme = {
    #   name = "xfce4-icon-theme";
    #   package = pkgs.xfce.xfce4-icon-theme;
    # };
    theme = {
      name = "matcha-dark-sea";
      package = pkgs.matcha-gtk-theme;
    };
    gtk3.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
    gtk4.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
  };

  # INFO: https://github.com/nix-community/home-manager/issues/1011#issuecomment-1452920285
  xdg.configFile."plasma-workspace/env/hm-session-vars.sh".text = ''
    . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
  '';

  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "/glacier/snowscape/desktop";
      documents = "/glacier/snowscape/documents";
      download = "/glacier/snowscape/downloads";
      music = "/glacier/snowscape/music";
      pictures = "/glacier/snowscape/photos";
    };
  };

  programs.vinyl-vault = {
    enable = true;
    rootDownloadPath = config.xdg.userDirs.music;
  };

  services.mpvd.enable = true;
  services.udiskie.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";

  xsession = {
    enable = true;
    scriptPath = ".hm-xsession";
    # initExtra = ''
    #   # xrdb -merge ~/.Xresources
    #   # /home/simonwjackson/layout.sh &
    #   # virtual-term start &
    #   # /home/simonwjackson/.nix-profile/bin/virtual-term
    # '';
    windowManager.command = lib.mkForce ''
      exec ${pkgs.herbstluftwm}/bin/herbstluftwm --locked
      # exec $(while true; do sleep 1; done)
      # exec ${pkgs.kitty}/bin/kitty
      # ${pkgs.openbox}/bin/openbox &
      # exec ${pkgs.xfce.xfwm4}/bin/xfwm4
      # exec ${pkgs.bspwm}/bin/bspwm -c /home/simonwjackson/bspwmrc
      # exec /home/simonwjackson/toggle-wm
    '';
  };

  # home.file."toggle-wm" = {
  #   executable = true;
  #   text = ''
  #     #!/usr/bin/env bash
  #
  #     # while true; do
  #           # Get the current window manager
  #           current_wm=$(${pkgs.wmctrl}/bin/wmctrl -m | grep Name | awk '{print $2}')
  #           current_pid=$(${pkgs.wmctrl}/bin/wmctrl -m | grep PID | awk '{print $2}')
  #
  #           kill -9 $current_pid
  #           sleep 1
  #           # Switch to the other window manager
  #           if [[ $current_wm == "bspwm" ]]; then
  #             ${pkgs.xfce.xfwm4}/bin/xfwm4
  #           else
  #             ${pkgs.bspwm}/bin/bspwm -c /home/simonwjackson/bspwmrc
  #           fi
  #     # done
  #   '';
  # };

  xresources = {
    properties = {
      "Xft.dpi" = "128";
      "Xcursor.size" = "32";
    };
  };

  xsession.windowManager.herbstluftwm = {
    enable = true;
    settings = {
      focus_follows_mouse = 1;
      gapless_grid = false;
      always_show_frame = false;
      frame_gap = 0;
      window_border_width = 0;
      frame_border_width = 0;
      window_border_active_color = "#FF0000";
      default_frame_layout = "max";
    };
    rules = [
      "windowtype~'_NET_WM_WINDOW_TYPE_(DIALOG|UTILITY|SPLASH)' focus=on pseudotile=on"
      "windowtype~'_NET_WM_WINDOW_TYPE_(NOTIFICATION|DOCK|DESKTOP)' manage=off"
    ];
    tags = ["main" "other"];
    # focus padding mode
    # herbstclient pad 0 200 500 200 500
    extraConfig = let
      padding = "25";
    in ''
      herbstclient set_layout max
      herbstclient detect_monitors
      herbstclient set window_gap ${padding}
      herbstclient pad 0 40 0 -${padding} 0
    '';
  };

  services.sxhkd = {
    enable = true;
    keybindings = let
      max-toggle = "${pkgs.herbstluftwm-scripts}/bin/herb-max-toggle";
      popup = "${pkgs.herbstluftwm-scripts}/bin/herb-popup";
      kitty = "${pkgs.kitty}/bin/kitty";
      term-popup = "${popup} ${kitty} --";
      hc = "${pkgs.herbstluftwm}/bin/herbstclient";
      brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
    in {
      "super + space" = ''
        ${term-popup} nmtui
      '';
      "super + ctrl + space" = ''
        ${max-toggle}
      '';
      "super + {_, shift} + Tab" = ''
        ${hc} cycle_all {+,-}1
      '';
      "super + Return" = ''
        ${kitty}
      '';
      "XF86Audio{Raise,Lower}Volume" = ''
        ${pkgs.pamixer}/bin/pamixer --{increase,decrease} 5
      '';
      "super + w" = ''
        ${pkgs.wmctrl}/bin/wmctrl -xa $BROWSER || $BROWSER
      '';
      "{XF86MonBrightnessDown,XF86MonBrightnessUp}" = ''
        ${brightnessctl} --device='*' --exponent set 5%{-,+}
      '';
      "super + {XF86MonBrightnessDown,XF86MonBrightnessUp}" = ''
        ${brightnessctl} --device='*' set {1,100}%
      '';
      "super + {h,j,k,l}" = ''
        ${hc} focus {left,down,up,right}
      '';
    };
  };

  fonts.fontconfig.enable = true;
  home.packages = [
    pkgs."material-icons"
    (pkgs.nerdfonts.override {
      fonts = [
        "Noto"
        "BitstreamVeraSansMono"
        # "Droid"
        "Iosevka"
        "FantasqueSansMono"
        "DroidSansMono"
        "Terminus"
      ];
    })
  ];

  services.polybar = {
    enable = true;
    # package = inputs.nixpkgs-unstable.polybar.override {
    #   alsaSupport = true;
    #   pulseSupport = true;
    # };
    script = "polybar top &";
    settings = let
      icons = {
        vpn = {
          active = "";
          inactive = "";
        };
        cpu = "";
        memory = "";
        date = "";
        microphone = "";
        microphone-muted = "";
        microphone-disconnected = "";
        wifi = "";
        up = "";
        down = "";
        ethernet = "";
        envelope = "";
      };

      background = "#99000000";
      background-alt = "#99000000";

      foreground = "#ffdddddd";
      foreground-alt = "#ffdddddd";

      primary = "#ff006633";
      secondary = "#ff003333";
      alert = "#ff330000";
      fonts = {
        font = [
          "DroidSansM Nerd Font Mono:style=Regular:pixelsize=12:antialias=true;0"
          # "NotoSansM Nerd Font Mono:antialias=true"
        ];
      };
    in {
      "bar/top" =
        fonts
        // {
          monitor = "\${env:MONITOR:eDP-1}";
          width = "100%";
          height = 20;
          offset-y = 26;
          # offset-x = 25;
          radius = 0;
          module-margin = 1;
          modules = {
            left = "empty-module tailscale xwindow";
            center = "time";
            right = "battery wlan empty-module";
          };
          # offset.y = 30;
        };

      "module/empty-module" = {
        type = "custom/text";
        content = " ";
        width = 25;
      };

      "module/xwindow" = {
        type = "internal/xwindow";
        label = "%title:0:30:...%";
      };

      "module/wlan" = {
        type = "internal/network";
        interval = "3.0";
        interface.type = "wireless";

        format-connected = "<ramp-signal> <label-connected>";
        label-connected = "%essid%";

        ramp = {
          signal = [
            "󰤯"
            "󰤟"
            "󰤢"
            "󰤥"
            "󰤨"
          ];
          signal-foreground = foreground-alt;
        };
      };

      "module/battery" = {
        type = "internal/battery";
        battery = "BAT1";
        adapter = "ADP1";
        full-at = "98";

        format.charging = "<ramp-capacity> <label-discharging>";
        format.discharging = "<ramp-capacity> <label-discharging>";
        format.full-prefix = " ";
        format-full-prefix-foreground = foreground;

        ramp.capacity = ["" "" ""];
        ramp-capacity-foreground = foreground;
      };

      # "module/notmuch" = {
      #   type = "custom/script";
      #   exec = "echo -n '${icons.envelope} '; ${pkgs.notmuch}/bin/notmuch search tag:unread | wc -l";
      #   tail = true;
      #   interval = 10;
      #   click-left = "${pkgs.astroid}/bin/astroid";
      # };
      #
      "module/tailscale" = {
        type = "custom/script";
        exec =
          # TODO: Move to own script file
          (pkgs.writeScriptBin "tailscale-check" ''
            #!/usr/bin/env bash
            # echo -n " ";
            # ${pkgs.tailscale}/bin/tailscale status | grep -o 'Connected' | wc -l

            ICON_ACTIVE="${icons.vpn.active}"
            ICON_INACTIVE="${icons.vpn.inactive}"

            status=$(curl --silent --fail --unix-socket /var/run/tailscale/tailscaled.sock http://local-tailscaled.sock/localapi/v0/status)

            # bail out if curl had non-zero exit code
            if [ $? != 0 ]; then
                exit 0
            fi

            # check if it's stopped (down)
            if [ "$(echo $status | jq --raw-output .BackendState)" = "Stopped" ]; then
                echo "$ICON_INACTIVE VPN down"
                exit 0
            fi

            # if an exit node is active, show its hostname
            exit_node_hostname="$(echo $status | jq --raw-output '.Peer[] | select(.ExitNode) | .HostName')"
            if [ -n "$exit_node_hostname" ]; then
                echo "$ICON_ACTIVE $exit_node_hostname"
            else
                echo "$ICON_ACTIVE"
            fi
          '')
          + "/bin/tailscale-check";
        tail = true;
        interval = 10;
        # click-left = "${pkgs.astroid}/bin/astroid";
      };

      # "module/headsetswitch" = let
      #   pactl = "${pkgs.pulseaudioLight}/bin/pactl";
      #   grep = "${pkgs.gnugrep}/bin/grep";
      #   sed = "${pkgs.gnused}/bin/sed";
      # in {
      #   type = "custom/script";
      #   format-underline = "#0628FF";
      #   label = "%output%";
      #   exec = __concatStringsSep " " [
      #     "${pactl} info"
      #     "| ${grep} 'Default Sink'"
      #     "| ${sed} 's/.*analog-stereo//'"
      #     "| ${sed} 's/.*analog-stereo//'"
      #     "| ${sed} 's/.*auto_null/${icons.microphone-disconnected}/'"
      #     "| ${sed} 's/.*hdmi-stereo-extra.*/HDMI/'"
      #     "| ${sed} 's/.*headset_head_unit/${icons.microphone}/'"
      #     "| ${sed} 's/.*a2dp_sink/${icons.microphone-muted}/'"
      #     "| ${sed} 's/.*hdmi-stereo/HDMI/'"
      #   ];
      #
      #   tail = true;
      #   interval = 2;
      #   click-left = "${pactl} set-card-profile bluez_card.2C_41_A1_83_C7_98 a2dp_sink";
      #   click-right = "${pactl} set-card-profile bluez_card.2C_41_A1_83_C7_98 headset_head_unit";
      # };

      "module/time" = {
        type = "internal/date";
        interval = "5";

        time = "%I:%M";

        format-underline = "#2406E8";
        label = "%time%";
      };
    };
  };
}
