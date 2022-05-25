{ config, pkgs, lib, ... }:

{
  imports = [
    ./polybar
    ./bspwm
  ];

  home = {
    sessionVariables = {
      MPV_SOCKET = "/tmp/mpv.socket";
    };

    file = {
      "./.config/tridactyl/tridactylrc" = {
        source = ./tridactylrc;
      };
    };

    packages = with pkgs; [
      brightnessctl
      tridactyl-native
      xfce.xfwm4
      adwaita-qt
      xorg.xwininfo
      wmctrl
      xorg.xkill
      tridactyl-native
      rofi
    ];
  };

  # xsession = {
  #   enable = true;
  #   scriptPath = ".hm-xsession";
  #   # windowManager.command = lib.mkForce ''
  #   #       # TESTING
  #   #       ${pkgs.bspwm} -c /home/simonwjackson/.config/bspwm/bspwmrc
  #   #       exec kitty
  #   # '';
  # };

  dconf.enable = true;
  gtk = {
    enable = true;
    theme.package = pkgs.gnome.gnome-themes-extra;
    theme.name = "Adwaita";

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  qt = {
    enable = true;
    platformTheme = "gnome";
    style.package = pkgs.adwaita-qt;
    style.name = "adwaita-dark";
  };

  programs.mpv = {
    enable = true;

    config = {
      input-ipc-server = "/tmp/mpv.socket";
      panscan = "1.0";
    };
  };

  programs.kitty = {
    enable = true;
    extraConfig = builtins.readFile (./kitty/kitty.conf);
  };

  services.picom = {
    enable = true;

    opacityRule = [
      "0:class_g^='VIRTUAL_TERM_'"
    ];
    extraOptions = builtins.readFile (./picom/picom.conf);
  };

  services.sxhkd = {
    enable = true;

    extraConfig = builtins.readFile (./sxhkd/sxhkdrc);
  };

  programs.firefox = {
    enable = true;
    # package = pkgs.firefox.override {
    #   # See nixpkgs' firefox/wrapper.nix to check which options you can use
    #   cfg = {
    #     # Tridactyl native connector
    #     enableTridactylNative = true;
    #   };
    # };

    package = pkgs.firefox.override
      {
        # See nixpkgs' firefox/wrapper.nix to check which options you can use
        cfg = {
          # Tridactyl native connector
          enableTridactylNative = true;
        };
      };

    profiles.simonwjackson = {
      isDefault = true;
      settings = { };

      userChrome = ''
        /* Hide tab bar in FF Quantum */
        @-moz-document url("chrome://browser/content/browser.xul") {
          #TabsToolbar {
            visibility: collapse !important;
            margin-bottom: 21px !important;
          }

          #sidebar-box[sidebarcommand="treestyletab_piro_sakura_ne_jp-sidebar-action"] #sidebar-header {
            visibility: collapse !important;
          }
        }
      '';

      userContent = ''
        /* Hide scrollbar in FF Quantum */
        *{scrollbar-width:none !important}
      '';
    };
  };
}

