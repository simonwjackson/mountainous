{
  config,
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkOption types;

  hyprlandEnabled = osConfig.programs.hyprland.enable or false;
  hostName = osConfig.networking.hostName or "";
  isYuki = hostName == "yuki";

  sharedHyprlandKeybindsConfig = import ../../features/hyprland/keybinds.nix {
    inherit config lib pkgs;
    inputs = {};
  };
  sharedHyprlandKeybinds = sharedHyprlandKeybindsConfig.keybinds;
  homeHyprlandKeybinds = {
    "$mainMod, Return" = {
      kind = "bind";
      action = "exec, $terminal";
    };
    "$mainMod, N" = {
      kind = "bind";
      action = "exec, darkman toggle";
    };
    "$mainMod CTRL, E" = {
      kind = "bind";
      action = "exit,";
    };
    ", Print" = {
      kind = "bind";
      action = ''exec, grim -g "$(slurp)" - | wl-copy'';
    };
  };
  finalHyprlandKeybinds = lib.filterAttrs (_: spec: spec != null) (
    sharedHyprlandKeybinds // homeHyprlandKeybinds // config.mountainous.hyprland.keybinds
  );
  renderHyprlandKeybinds = kind:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (combo: spec: "      ${kind} = ${combo}, ${spec.action}") (
        lib.filterAttrs (_: spec: spec.kind == kind) finalHyprlandKeybinds
      )
    );

  ironbarBar = {
    position = "top";
    height = 32;
    start = [
      {
        type = "workspaces";
        favorites = [
          "1"
          "2"
          "3"
          "4"
          "5"
        ];
      }
    ];
    center = [
      {
        type = "clock";
        format = "%-I:%M";
      }
    ];
    end = [
      {
        type = "custom";
        class = "codexbar";
        bar = [
          {
            type = "button";
            label = "{{120000:codexbar-claude}}";
            on_click = "popup:toggle";
          }
        ];
        popup = [
          {
            type = "box";
            orientation = "vertical";
            widgets = [
              {
                type = "label";
                label = "{{120000:codexbar-claude-detail}}";
              }
            ];
          }
        ];
      }
      {
        type = "custom";
        class = "codexbar";
        bar = [
          {
            type = "button";
            label = "{{120000:codexbar-codex}}";
            on_click = "popup:toggle";
          }
        ];
        popup = [
          {
            type = "box";
            orientation = "vertical";
            widgets = [
              {
                type = "label";
                label = "{{120000:codexbar-codex-detail}}";
              }
            ];
          }
        ];
      }
      {
        type = "volume";
        format = "{icon} {percentage}%";
      }
      {
        type = "network_manager";
        icon_size = 18;
      }
      {
        type = "battery";
        format = "{percentage}%";
        thresholds = {
          warning = 20;
          critical = 5;
        };
      }
      {
        type = "tray";
        icon_size = 16;
      }
    ];
  };
  ironbarConfig =
    if isYuki
    then {
      start = null;
      center = null;
      end = null;
      monitors = {
        "eDP-1" = ironbarBar;
        "DP-1" = ironbarBar;
      };
    }
    else ironbarBar;
in {
  imports = [
    ../../modules/home/codexbar
  ];

  options.mountainous.hyprland.extraSettings = mkOption {
    type = types.attrsOf types.anything;
    default = {};
    description = "Extra Hyprland settings (stub for gaming module compatibility)";
  };

  options.mountainous.hyprland.keybinds = mkOption {
    type = types.attrsOf (
      types.nullOr (
        types.submodule {
          options = {
            kind = mkOption {
              type = types.enum [
                "bind"
                "bindel"
                "bindl"
                "bindm"
              ];
              description = "Which Hyprland bind keyword to render for this key chord.";
            };

            action = mkOption {
              type = types.str;
              description = "The dispatcher and arguments, e.g. `exec, kitty`.";
            };
          };
        }
      )
    );
    default = {};
    description = ''
      Per-host Hyprland keybinding overrides keyed by key chord.

      Use the same key to replace a shared binding, or set it to `null` to remove it.
    '';
  };

  config = {
    mountainous.codexbar.enable = true;

    home.stateVersion = "24.11";

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableBashIntegration = true;
      config = {
        whitelist.prefix = ["/home/simonwjackson/code"];
      };
    };

    programs.atuin = {
      enable = true;
      enableBashIntegration = true;
      daemon.enable = true;
      settings = {
        auto_sync = true;
        enter_accept = true;
        filter_mode_shell_up_key_binding = "workspace";
        inline_height = 10;
        search_mode = "fuzzy";
        secrets_filter = false;
        style = "compact";
        sync_address = "https://api.atuin.sh";
        sync_frequency = "5m";
      };
    };

    home.sessionPath = [
      "$HOME/.nix-profile/bin"
      "$HOME/.local/bin"
      "/etc/profiles/per-user/simonwjackson/bin"
      "/run/current-system/sw/bin"
    ];

    home.shellAliases = {
      ll = "ls -l";
      la = "ls -a";
      lla = "ls -la";
      g = "git";
      gs = "git status";
      gd = "git diff";
      gl = "git log --oneline -20";
      gp = "git push";
      gc = "git commit";
      rebuild = "sudo nixos-rebuild switch --flake ~/code/fuji";
    };

    programs.carapace = {
      enable = true;
      enableBashIntegration = true;
    };

    programs.starship = {
      enable = true;
      enableBashIntegration = true;
      settings = {
        add_newline = false;
        format = "$directory$git_branch$git_status$nix_shell$character";
        directory = {
          truncation_length = 3;
          style = "bold cyan";
        };
        git_branch = {
          format = "[$branch]($style) ";
          style = "bold purple";
        };
        git_status = {
          format = "[$all_status$ahead_behind]($style) ";
          style = "bold red";
        };
        nix_shell = {
          format = "[$symbol$state]($style) ";
          symbol = "❄️ ";
        };
        character = {
          success_symbol = "[›](bold green)";
          error_symbol = "[›](bold red)";
        };
      };
    };

    programs.bash = {
      enable = true;
      initExtra = ''
        if [[ -f /run/agenix/openclaw-env ]]; then
          while IFS= read -r line; do
            case "$line" in
              OPENCLAW_GATEWAY_TOKEN=*)
                export OPENCLAW_GATEWAY_TOKEN="''${line#OPENCLAW_GATEWAY_TOKEN=}"
                break
                ;;
            esac
          done < /run/agenix/openclaw-env
        fi
      '';
    };

    programs.kitty = {
      enable = true;
    };

    gtk = lib.mkIf hyprlandEnabled {
      enable = true;
      iconTheme = {
        package = pkgs.adwaita-icon-theme;
        name = "Adwaita";
      };
    };

    home.packages = with pkgs;
      lib.optionals hyprlandEnabled [
        ironbar
        tofi
        wl-clipboard
        grim
        slurp
        brightnessctl
        pavucontrol
        networkmanagerapplet
      ];

    xdg.configFile = lib.mkIf hyprlandEnabled {
      "hypr/hyprland.conf".text = ''
              $mod = ${sharedHyprlandKeybindsConfig."$mainMod"}
              $mainMod = ${sharedHyprlandKeybindsConfig."$mainMod"}
              $terminal = ${sharedHyprlandKeybindsConfig."$terminal"}
              $fileManager = ${sharedHyprlandKeybindsConfig."$fileManager"}
              $menu = tofi-drun

              ${lib.optionalString (!isYuki) ''
          monitor = eDP-1, 2880x1800@60, 0x0, 1, transform, 2
                monitor = eDP-2, 2880x1800@60, 0x1800, 1''}

              ${lib.optionalString isYuki ''
          # Yuki-specific visual baseline
          # -----------------------------
          # Keep the desktop background as a plain solid black. That fits the dual-OLED
          # hardware well and avoids distracting default wallpaper or splash visuals.
          misc:force_default_wallpaper = 0
          misc:background_color = 0x000000

          # Yuki-specific single-window layout
          # ---------------------------------
          # When a workspace only has one tiled or fullscreen window, let the app use the
          # whole panel instead of keeping outer gaps and rounded corners.
          workspace = w[tv1], gapsout:0, gapsin:0
          workspace = f[1], gapsout:0, gapsin:0
          windowrule = bordersize 0, floating:0, onworkspace:w[tv1]
          windowrule = rounding 0, floating:0, onworkspace:w[tv1]
          windowrule = bordersize 0, floating:0, onworkspace:f[1]
          windowrule = rounding 0, floating:0, onworkspace:f[1]''}

              # Host-specific Hyprland quirks live in separately managed files so laptop-specific
              # tweaks do not get buried in this generic user config.
              ${lib.optionalString isYuki ''source = ${
            config.xdg.configFile."hypr/yuki-quirks.conf".source
          }''}

              # Source yuki's generated monitor layout after the bootstrap workaround file so
              # HyprDynamicMonitors can override the static internal-only layout once it has
              # written ~/.config/hypr/monitors.conf.
              ${lib.optionalString isYuki ''source = ~/.config/hypr/monitors.conf''}

              exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR XDG_CURRENT_DESKTOP=Hyprland
              exec-once = systemctl --user start graphical-session.target
              exec-once = nm-applet --indicator
              exec-once = ironbar

              env = XCURSOR_SIZE,24
              env = NIXOS_OZONE_WL,1

              input {
                kb_layout = us
                follow_mouse = 1
                touchpad {
                  natural_scroll = false
                  tap-to-click = true
                  disable_while_typing = true
                }
              }

              general {
                gaps_in = 4
                gaps_out = 8
                border_size = 0
                layout = dwindle
              }

              decoration {
                rounding = 8
              }

              animations {
                enabled = false
              }

              dwindle {
                pseudotile = true
                preserve_split = true
              }

              misc {
                disable_hyprland_logo = true
                force_default_wallpaper = 0
                background_color = 0x000000
              }

        ${renderHyprlandKeybinds "bind"}
        ${lib.optionalString (renderHyprlandKeybinds "bindel" != "") ''

          ${renderHyprlandKeybinds "bindel"}''}
        ${lib.optionalString (renderHyprlandKeybinds "bindl" != "") ''

          ${renderHyprlandKeybinds "bindl"}''}
        ${lib.optionalString (renderHyprlandKeybinds "bindm" != "") ''

          ${renderHyprlandKeybinds "bindm"}''}
      '';

      "ironbar/config.json".text = builtins.toJSON ironbarConfig;

      "ironbar/style.css".text = ''
        * {
          font-family: monospace, "Symbols Nerd Font";
          font-size: 12px;
        }

        .background {
          background-color: transparent;
          color: #ffffff;
        }

        #bar {
          padding: 0 6px;
        }

        .widget {
          margin: 0 2px;
          background: transparent;
        }

        .workspaces .item,
        .clock,
        .volume,
        .network_manager,
        .battery,
        .tray,
        .script,
        button {
          padding: 0 8px;
          background: transparent;
          box-shadow: none;
        }

        .codexbar button {
          padding: 0 6px;
        }

        .popup-codexbar {
          padding: 12px 16px;
          font-family: monospace;
          font-size: 12px;
        }

        .popup {
          background-color: @theme_bg_color;
          color: @theme_fg_color;
          border: 1px solid @borders;
          border-radius: 8px;
          padding: 8px;
        }
      '';
    };

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks."aso" = {
        port = 8080;
      };
      matchBlocks."*" = {
        forwardAgent = false;
        addKeysToAgent = "no";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };
    };

    programs.git = {
      enable = true;
      settings.user = {
        name = "Simon W. Jackson";
        email = "simon@simonwjackson.io";
      };
    };

    programs.lazygit = {
      enable = true;
      settings = {
        keybinding.files = {
          commitChanges = "C";
          commitChangesWithEditor = "C";
        };
        customCommands = [
          {
            key = "c";
            context = "files";
            description = "Split changes into logical AI commits";
            command = "nix run nixpkgs#bun -- x @mariozechner/pi-coding-agent -p --no-session --tools bash,read,grep,find,ls --model 'claude-haiku-4-5' --thinking off --append-system-prompt 'First determine the candidate change set: if any changes are staged, operate only on the currently staged changes. If nothing is staged, operate on all current working tree changes, including untracked files, but not ignored files. Split the candidate change set into the minimum sensible number of logical commits. You may inspect diffs, stage, unstage, and restage changes, including hunk splitting if needed. Do not edit file contents. Do not pull, push, rebase, amend old commits, or touch ignored files. When finished, output only a concise list of the commits you created as <sha> <subject>.' 'Split the repository changes into logical commits and create them.'";
            loadingText = "🤖 Creating logical commits...";
            output = "none";
          }
        ];
        promptToReturnFromSubprocess = false;
      };
    };
  };
}
