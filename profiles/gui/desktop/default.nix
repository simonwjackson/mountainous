{ ... }: {
  home-manager.users.simonwjackson = { lib, config, pkgs, ... }: {

    imports = [
      # ./bspwm
    ];

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
        # miscPostInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        #   nix-shell -p python3Packages.pip --run 'pip install --user pywalfox shell_gpt'
        #   # TODO: Needs sudo
        #   # ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        # '';
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

        # "./.local/bin" = {
        #   source = ../../../modules/cmd_p;
        #   recursive = true;
        # };

        "./.config/tridactyl/tridactylrc" = {
          source = ./tridactylrc;
        };

        # "./.local/bin/all-monitors-brightnessctl" = {
        #   source = pkgs.writeScript "all-monitors-brightnessctl" ''
        #     brightnessctl -l \
        #       | awk -F"'" '/backlight/ {print $2}' \
        #       | grep backlight \
        #       | xargs -I '@' brightnessctl -d '@' $@
        #   '';
        # };

        "./.local/bin/terminal-desktop-bspwm" = {
          source = pkgs.writeScript "terminal-desktop-bspwm" ''
            # Define 'main-term' once
            # main_term="main-term"

            # Start a terminal named 'main-term' on the desktop 'terminal'
            # bspc rule -a $main_term desktop='^terminal$'
            bspc rule --add "*:*:main-term" desktop='terminal'

            # Listen for window creation events

            bspc subscribe node_add | while read -r event _ windowId _ nodeId; do
              # Check if the new window was created on the 'terminal' desktop
              desk_id=$(bspc query -D -d)
              desk_name=$(bspc query -D -d "$desk_id" --names)
              win_name=$(xprop -id "$windowId" | awk -F\" '/WM_NAME/{print $2}' | head -n 1)

              if [ "$desk_name" = "terminal" ] && [ "$event" = "node_add" ] && [ "$win_name" != "main-term" ]; then
                # Find the ID of the next available desktop
                next_desk_id=$(bspc query -D | awk -v curr="$desk_id" '$0 != curr {print; exit}')
                # Move the new window to the next available desktop
                bspc node "$nodeId" -d "$next_desk_id"
              fi
            done &

            # while true; do
            #   # Get the list of all windows in the 'terminal' desktop
            #   windows="$(bspc query -W -d terminal)"
            #
            #   # Initialize a flag to track if the 'main-term' window is found
            #   main_term_found=0
            #
            #   # Iterate over each window
            #   for window in $windows; do
            #     # Get the window's name
            #     window_name=$(xprop -id "$window" | awk -F\" '/WM_NAME/ {print $2}' | head -n 1)
            #
            #     # If the window's name is 'main-term', set the flag to 1
            #     if [[ $window_name == "main-term" ]]; then
            #       main_term_found=1
            #       break
            #     fi
            #   done
            #
            #   # If the 'main-term' window was not found, launch the script
            #   if [[ $main_term_found -eq 0 ]]; then
            #     /path/to/main-term.sh
            #   fi
            #
            #   # Wait for a while before the next check
            #   sleep 5
            # done &

            # Handle script termination
            cleanup() {
              jobs -p | xargs kill
            }

            trap cleanup EXIT

            # Wait for subscriptions
            wait
          '';
        };

        "./.local/bin/better-monocle-mode" = {
          source = pkgs.writeScript "better-monocle-mode" ''
            # Function to change the opacity of a window
            set_opacity() {
              picom-trans -w "$1" "$2"
            }

            get_currently_focused_window() {
              bspc query -N -n
            }

            get_all_windows_current_desktop() {
              bspc query -N -d
            }

            opacity="90%"

            set_opacity_based_on_layout() {
              local now_focused=$(get_currently_focused_window)
              local all_windows=$(get_all_windows_current_desktop)

              for win in $all_windows; do
                if [ "$win" == "$now_focused" ]; then
                  set_opacity "$win" "$opacity"
                else
                  set_opacity "$win" "0"
                fi
              done
            }

            set_opacity_all_windows() {
              for win in $(get_all_windows_current_desktop); do set_opacity "$win" "$opacity"; done
            }

            handle_node_focus_change() {
              if [ "$(bspc query -T -d | jq -r '.layout')" == "monocle" ]; then
                set_opacity_based_on_layout
              fi
            }

            handle_desktop_layout_change() {
              if [ "$layout" == "monocle" ]; then
                set_opacity_based_on_layout
              else
                set_opacity_all_windows
              fi
            }

            # Subscribe to changes
            bspc subscribe node_focus | while read -r; do handle_node_focus_change; done &
            bspc subscribe desktop_layout | while read -r _ _ _ layout; do handle_desktop_layout_change; done &

            # Handle script termination
            cleanup() {
              jobs -p | xargs kill
            }

            trap cleanup EXIT

            # Wait for subscriptions
            wait
          '';
        };

        "./.local/bin/main-term" = {
          source = pkgs.writeScript "main-term" ''
            tmux \
              -f ~/.config/tmux/tmux.workspace.conf \
              -L WORKSPACE new-session \
              -d \
              -s terminals \
              nvim -c "terminal" -c "startinsert"; \
            tmux \
              -f ~/.config/tmux/tmux.host.conf \
              -L HOST \
              new-session \
              -d \
              -c "$HOME" \
              -s "$(hostname)" \
              mosh localhost -- sh -c 'tmux -L WORKSPACE attach-session -t terminals'; \
            xdotool search \
              --name "main-term" \
              windowactivate || \
              ${pkgs.kitty}/bin/kitty \
                -o allow_remote_control=yes \
                --title=main-term \
                sh -c 'cat ~/.cache/wal/sequences; tmux -L HOST attach-session -t "$(hostname)"'
          '';
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
        (pkgs.nerdfonts.override {
          fonts = [
            "BitstreamVeraSansMono"
            "Noto"
          ];
        })
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
        pywal
      ] ++ [ ];
    };


    # home.file.".config/awesome".source = config.lib.file.mkOutOfStoreSymlink ./awesome;
    # home.file.".config/awesome/scratch.lua".source = config.lib.file.mkOutOfStoreSymlink ./awesome/scratch.lua;

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

    home.file.".config/kitty/kitty.conf".source = config.lib.file.mkOutOfStoreSymlink ./kitty/kitty.conf;

    # services.picom = {
    #   enable = true;
    #   settings = import ./picom/picom.nix;

    #   # extraArgs = [ "--experimental-backend" ];
    #   # package = pkgs.picom.overrideAttrs (o: {
    #   #   src = pkgs.fetchFromGitHub {
    #   #     repo = "picom";
    #   #     owner = "jonaburg";
    #   #     rev = "e3c19cd7d1108d114552267f302548c113278d45";
    #   #     sha256 = "4voCAYd0fzJHQjJo4x3RoWz5l3JJbRvgIXn1Kg6nz6Y=";
    #   #   };
    #   # });
    # };

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
          /* Here all specific rules for user interface, extensions UI… */
          @-moz-document url(chrome://browser/content/browser.xul),
            url(chrome://browser/content/browser.xhtml),
            url(chrome://browser/content/places/bookmarksSidebar.xhtml),
            url(chrome://browser/content/webext-panels.xhtml),
            url(chrome://browser/content/places/places.xhtml) {
            :root[titlepreface*="᠎"] #TabsToolbar > .toolbar-items {
              opacity: 0;
              pointer-events: none;
            }
            
            :root[titlepreface*="᠎"] #TabsToolbar {
              visibility: collapse !important;
            }
            
            :root[titlepreface*="᠎"] #TabsToolbar .titlebar-spacer {
              border-inline-end: none;
            }

            :root[titlepreface*="᠎"] #nav-bar {
              visibility: inherit !important;
              visibility: collapse !important;
            }

            #home-button {
              display: none !important;
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

