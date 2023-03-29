{ config, pkgs, lib, ... }:

{
  imports = [
    ./polybar
    # ./bspwm
  ];

  home = {
    sessionVariables = {
      MPV_SOCKET = "/tmp/mpv.socket";
    };

    file = {
      "./.local/bin" = {
        source = ../../../modules/cmd_p;
        recursive = true;
      };

      "./.config/tridactyl/tridactylrc" = {
        source = ./tridactylrc;
      };
      "./.local/bin/wm" = {
        source = pkgs.writeScript "wm" (builtins.readFile ./wm.sh);
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
      pamixer
      rofi
    ];
  };

  xsession.windowManager.awesome = {
    enable = true;
  };

  home.file.".config/awesome/rc.lua".source = config.lib.file.mkOutOfStoreSymlink ./awesome/rc.lua;

  xsession = {
    enable = true;
    scriptPath = ".hm-xsession";
    initExtra = ''
      xrdb -merge ~/.Xresources
      # /home/simonwjackson/layout.sh &
      # virtual-term start &
      # /home/simonwjackson/.nix-profile/bin/virtual-term
    '';
    # windowManager.command = lib.mkForce ''
    #       # TESTING
    #       ${pkgs.bspwm} -c /home/simonwjackson/.config/bspwm/bspwmrc
    #       exec kitty
    # '';
  };

  # dconf.enable = true;
  # gtk = {
  #   enable = true;
  #   theme.package = pkgs.gnome.gnome-themes-extra;
  #   theme.name = "Adwaita";

  #   gtk4.extraConfig = {
  #     gtk-application-prefer-dark-theme = 1;
  #   };

  #   gtk3.extraConfig = {
  #     gtk-application-prefer-dark-theme = 1;
  #   };
  # };

  # qt = {
  #   enable = true;
  #   platformTheme = "gnome";
  #   style.package = pkgs.adwaita-qt;
  #   style.name = "adwaita-dark";
  # };

  programs.mpv = {
    enable = true;

    config = {
      input-ipc-server = "/tmp/mpv.socket";
      panscan = "1.0";
    };
  };

  home.file.".config/kitty/kitty.base.conf".source = config.lib.file.mkOutOfStoreSymlink ./kitty/kitty.conf;

  services.picom = {
    enable = false;
    extraArgs = [ "--experimental-backend" ];
    settings = import ./picom/picom.nix;

    package = pkgs.picom.overrideAttrs (o: {
      src = pkgs.fetchFromGitHub {
        repo = "picom";
        owner = "jonaburg";
        rev = "e3c19cd7d1108d114552267f302548c113278d45";
        sha256 = "4voCAYd0fzJHQjJo4x3RoWz5l3JJbRvgIXn1Kg6nz6Y=";
      };
    });
  };

  services.sxhkd = {
    enable = true;

    extraConfig = builtins.readFile (./sxhkd/sxhkdrc);
  };

  programs.firefox = {
    enable = true;

    package = pkgs.firefox-esr.override {
      # See nixpkgs' firefox/wrapper.nix to check which options you can use
      cfg = {
        # Tridactyl native connector
        enableTridactylNative = true;
      };
    };

    profiles.simonwjackson = {
      isDefault = true;
      settings = {
        "signon.rememberSignons" = false;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "browser.tabs.closeWindowWithLastTab" = true;
        "layout.css.prefers-color-scheme.content-override" = 2;
        "xpinstall.signatures.required" = false;
        "extensions.langpacks.signatures.required" = false;
      };

      userChrome = ''
        /* Hide back/forward buttons */
        #back-button, #forward-button, #home-button { display:none!important; }
        
        /* Hide tab bar */
        #main-window[tabsintitlebar="true"]:not([extradragspace="true"]) #TabsToolbar > .toolbar-items {
          opacity: 0;
          pointer-events: none;
        }

        #main-window:not([tabsintitlebar="true"]) #TabsToolbar {
          visibility: collapse !important;
        }

        #main-window[tabsintitlebar="true"]:not([extradragspace="true"]) #TabsToolbar .titlebar-spacer {
          border-inline-end: none;
        }
      '';

      userContent = ''
        /* Hide scrollbar in FF Quantum */
        * { scrollbar-width: none !important }
      '';
    };
  };
}

