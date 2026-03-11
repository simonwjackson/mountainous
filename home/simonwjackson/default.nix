{ config, lib, pkgs, osConfig ? {}, ... }:

let
  hyprlandEnabled = osConfig.programs.hyprland.enable or false;
in
{
  home.stateVersion = "24.11";

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableNushellIntegration = true;
    config = {
      whitelist.prefix = [ "/home/simonwjackson/code" ];
    };
  };

  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
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

  programs.nushell = {
    enable = true;
    configFile.text = ''
      $env.config = {
        show_banner: false
        edit_mode: emacs
        
        completions: {
          case_sensitive: false
          quick: true
          partial: true
          algorithm: fuzzy
        }

        table: {
          mode: rounded
          index_mode: auto
        }

        history: {
          max_size: 100_000
          sync_on_enter: true
          file_format: sqlite
        }
      }
    '';
    envFile.text = ''
      $env.PATH = ($env.PATH | split row (char esep)
        | prepend "/run/current-system/sw/bin"
        | prepend "/etc/profiles/per-user/simonwjackson/bin"
        | prepend $"($env.HOME)/.local/bin"
        | prepend $"($env.HOME)/.nix-profile/bin"
        | uniq)

      # Load OpenClaw gateway token from system agenix secret
      if ("/run/agenix/openclaw-env" | path exists) {
        $env.OPENCLAW_GATEWAY_TOKEN = (open /run/agenix/openclaw-env | lines | where ($it | str starts-with "OPENCLAW_GATEWAY_TOKEN=") | first | split row "=" | skip 1 | str join "=")
      }
    '';
    shellAliases = {
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
  };

  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
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
  };

  programs.kitty = {
    enable = true;
  };

  home.packages = with pkgs;
    lib.optionals hyprlandEnabled [
      waybar
      wofi
      wl-clipboard
      grim
      slurp
      brightnessctl
      pavucontrol
      networkmanagerapplet
    ];

  xdg.configFile = lib.mkIf hyprlandEnabled {
    "hypr/hyprland.conf".text = ''
      $mod = SUPER
      $terminal = kitty
      $menu = wofi --show drun

      ${lib.optionalString ((osConfig.networking.hostName or "") != "yuki") ''monitor = eDP-1, 2880x1800@60, 0x0, 1, transform, 2
      monitor = eDP-2, 2880x1800@60, 0x1800, 1''}

      # Host-specific Hyprland quirks live in separately managed files so laptop-specific
      # workarounds do not get buried in this generic user config.
      ${lib.optionalString ((osConfig.networking.hostName or "") == "yuki") ''source = ~/.config/hypr/yuki-workarounds.conf''}

      exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland
      exec-once = nm-applet --indicator
      exec-once = waybar

      env = XCURSOR_SIZE,24
      env = NIXOS_OZONE_WL,1

      input {
        kb_layout = us
        follow_mouse = 1
        touchpad {
          natural_scroll = false
          tap-to-click = true
        }
      }

      general {
        gaps_in = 4
        gaps_out = 8
        border_size = 2
        layout = dwindle
      }

      decoration {
        rounding = 8
      }

      animations {
        enabled = true
      }

      dwindle {
        pseudotile = true
        preserve_split = true
      }

      misc {
        disable_hyprland_logo = true
      }

      bind = $mod, Return, exec, $terminal
      bind = $mod, D, exec, $menu
      bind = $mod SHIFT, Q, killactive,
      bind = $mod SHIFT, E, exit,
      bind = $mod, F, fullscreen,
      bind = $mod, V, togglefloating,
      bind = $mod, P, exec, pavucontrol

      bind = $mod, H, movefocus, l
      bind = $mod, L, movefocus, r
      bind = $mod, K, movefocus, u
      bind = $mod, J, movefocus, d

      bind = $mod SHIFT, H, movewindow, l
      bind = $mod SHIFT, L, movewindow, r
      bind = $mod SHIFT, K, movewindow, u
      bind = $mod SHIFT, J, movewindow, d

      bind = $mod, 1, workspace, 1
      bind = $mod, 2, workspace, 2
      bind = $mod, 3, workspace, 3
      bind = $mod, 4, workspace, 4
      bind = $mod, 5, workspace, 5
      bind = $mod, 6, workspace, 6
      bind = $mod, 7, workspace, 7
      bind = $mod, 8, workspace, 8
      bind = $mod, 9, workspace, 9
      bind = $mod, 0, workspace, 10

      bind = $mod SHIFT, 1, movetoworkspace, 1
      bind = $mod SHIFT, 2, movetoworkspace, 2
      bind = $mod SHIFT, 3, movetoworkspace, 3
      bind = $mod SHIFT, 4, movetoworkspace, 4
      bind = $mod SHIFT, 5, movetoworkspace, 5
      bind = $mod SHIFT, 6, movetoworkspace, 6
      bind = $mod SHIFT, 7, movetoworkspace, 7
      bind = $mod SHIFT, 8, movetoworkspace, 8
      bind = $mod SHIFT, 9, movetoworkspace, 9
      bind = $mod SHIFT, 0, movetoworkspace, 10

      bindm = $mod, mouse:272, movewindow
      bindm = $mod, mouse:273, resizewindow

      bind = , Print, exec, grim -g "$(slurp)" - | wl-copy
    '';

    "waybar/config.jsonc".text = ''
      {
        "layer": "top",
        "position": "top",
        "modules-left": ["hyprland/workspaces"],
        "modules-center": ["clock"],
        "modules-right": ["pulseaudio", "network", "battery", "tray"],
        "hyprland/workspaces": {
          "format": "{name}"
        },
        "clock": {
          "format": "{:%a %Y-%m-%d %H:%M}"
        },
        "pulseaudio": {
          "format": "VOL {volume}%",
          "format-muted": "MUTED"
        },
        "network": {
          "format-wifi": "{essid}",
          "format-ethernet": "wired",
          "format-disconnected": "offline"
        },
        "battery": {
          "format": "BAT {capacity}%"
        },
        "tray": {
          "spacing": 8
        }
      }
    '';

    "waybar/style.css".text = ''
      * {
        font-family: monospace;
        font-size: 12px;
      }

      window#waybar {
        background: rgba(20, 20, 20, 0.9);
        color: #e6e6e6;
      }

      #workspaces button,
      #clock,
      #pulseaudio,
      #network,
      #battery,
      #tray {
        padding: 0 8px;
      }
    '';
  };

  programs.git = {
    enable = true;
    userName = "Simon W. Jackson";
    userEmail = "simon@simonwjackson.io";
  };
}
