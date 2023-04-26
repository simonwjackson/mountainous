{ ... }:

{
  home-manager.users.simonwjackson = { lib, config, pkgs, ... }: {
    programs.vscode = {
      enable = true;
      userSettings = {
        "workbench.colorTheme" = "Wal Bordered";
        "window.menuBarVisibility" = "toggle";
        "editor.minimap.enabled" = false;
      };
    };

    home = {
      activation = {
        vscodeExtension = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          # Install
          comm -23 <(cat ~/.config/Code/extensions.txt | sort) <(${pkgs.vscode}/bin/code --list-extensions | sort) | xargs ${pkgs.vscode}/bin/code  --install-extension
          # Uninstall
          comm -23 <(${pkgs.vscode}/bin/code  --list-extensions | sort) <(cat ~/.config/Code/extensions.txt | sort) | xargs ${pkgs.vscode}/bin/code --uninstall-extension
        '';
      };

      file = {
        "./.config/Code/extensions.txt" = {
          text = ''
            bbenoist.Nix
            dlasagno.wal-theme
            GitHub.copilot
            asvetliakov.vscode-neovim
            ms-vsliveshare.vsliveshare
          '';
        };

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

        "./.local/bin/wallpaper-span" = {
          source = pkgs.writeScript "wallpaper-span" ''
            ${pkgs.feh}/bin/feh --bg-scale "$1" --no-xinerama
            IMAGE=$1 bash -c '${pkgs.python3Packages.pywal}/bin/wal -q -n -i $IMAGE' &
            for nvim_instance in $(nvr --serverlist); do
              nvr --nostart --servername "$nvim_instance" +':colorscheme pywal'
            done
            pywalfox update
          '';
        };

      };

      packages = with pkgs; [
        nerdfonts
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
      ] ++ [ ];
    };


    home.file.".config/awesome".source = config.lib.file.mkOutOfStoreSymlink ./awesome;
    # home.file.".config/awesome/scratch.lua".source = config.lib.file.mkOutOfStoreSymlink ./awesome/scratch.lua;

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

    home.file.".config/kitty/kitty.base.conf".source = config.lib.file.mkOutOfStoreSymlink ./kitty/kitty.conf;

    services.picom = {
      enable = true;
      settings = import ./picom/picom.nix;

      extraArgs = [ "--experimental-backend" ];
      # package = pkgs.picom.overrideAttrs (o: {
      #   src = pkgs.fetchFromGitHub {
      #     repo = "picom";
      #     owner = "jonaburg";
      #     rev = "e3c19cd7d1108d114552267f302548c113278d45";
      #     sha256 = "4voCAYd0fzJHQjJo4x3RoWz5l3JJbRvgIXn1Kg6nz6Y=";
      #   };
      # });
    };

    services.sxhkd = {
      enable = true;

      extraConfig = lib.mkMerge [
        (builtins.readFile (./sxhkd/sxhkdrc))
      ];
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
          :root[titlepreface*="᠎"] #nav-bar {
            visibility: inherit !important;
          }
          
          /* Here all specific rules for user interface, extensions UI… */
          @-moz-document url(chrome://browser/content/browser.xul),
            url(chrome://browser/content/browser.xhtml),
            url(chrome://browser/content/places/bookmarksSidebar.xhtml),
            url(chrome://browser/content/webext-panels.xhtml),
            url(chrome://browser/content/places/places.xhtml) {
          
            /* Hide back, forward & home buttons */
            #back-button,
            #forward-button,
            #home-button,
            #PersonalToolbar {
              display: none !important;
            }
          
            #nav-bar {
              visibility: collapse !important;
            }
          
            /* #urlbar-container {
              visibility: collapse !important;
            } */
          
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
          }
        '';

        userContent = ''
          /* Hide scrollbar in FF Quantum */
          * { scrollbar-width: none !important }
        '';
      };
    };
  };
}

