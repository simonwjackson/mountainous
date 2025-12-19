# This file (and the global directory) holds config that i use on all hosts
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (lib) mkIf mkDefault mkEnableOption;
in {
  options.mountainous.profiles.base = {
    enable = mkEnableOption "Whether to enable the base profile.";
  };

  config = lib.mkIf config.mountainous.profiles.base.enable {
    # VPN secret for vpn-ns tool
    # Note: Using rekeyFile for agenix-rekey integration. The secret is auto-discovered
    # from secrets/system/networking/, but we override ownership here.
    age.secrets."fastest-vpn" = {
      rekeyFile = lib.mkDefault ../../../secrets/system/networking/fastest-vpn.age;
      owner = lib.mkForce "simonwjackson";
      group = lib.mkForce "users";
      mode = lib.mkForce "400";
    };

    # GitHub token for nix config (used for private flake access)
    # Note: This is a user secret, auto-discovered from secrets/user/simonwjackson/credentials/
    # We add it to system secrets by declaring it with rekeyFile
    age.secrets."github-token-nix" = {
      rekeyFile = ../../../secrets/user/simonwjackson/credentials/github-token-nix.age;
      owner = mkDefault "root";
      group = mkDefault "root";
      mode = mkDefault "400";
    };

    # Pandora password for pyxis (username is in config file)
    age.secrets."pandora-password" = {
      rekeyFile = ../../../secrets/user/simonwjackson/credentials/pandora-password.age;
      owner = mkDefault "simonwjackson";
      group = mkDefault "users";
      mode = mkDefault "400";
    };

    networking.firewall.allowedTCPPorts = [
      8081 # Expo GO
    ];

    networking.firewall.enable = false;

    networking.enableIPv6 = false;

    programs.mosh.enable = true;
    programs.tmesh = {
      enable = mkDefault true;

      apps = [
        {
          name = "shell";
          cmd = "$SHELL";
          icon = "";
        }
        {
          name = "btop";
          cmd = "btop";
          icon = "󱤘";
        }
        {
          name = "yazi";
          cmd = "yazi";
          icon = "";
        }
        {
          name = "pyxis";
          cmd = "pyxis tui";
          icon = "󰎄";
        }
      ];

      # Server-side tmux config (runs on remote host)
      tmeshServerTmuxConfig = ''
        # Extended keys support (CSI u / kitty keyboard protocol)
        set -s extended-keys on
        set -as terminal-features ',*:extkeys'

        # Clipboard passthrough for nested tmux
        # INFO: https://github.com/tmux/tmux/wiki/Clipboard#terminal-support---tmux-inside-tmux
        set -s set-clipboard on
        set -g allow-passthrough on

        # Session behavior
        set-option -g detach-on-destroy off
        unbind-key -T root MouseDown3Pane

        # Performance
        set-option -g focus-events on
        set-option -s escape-time 0

        # Silent operation
        set-option -g visual-activity off
        set-option -g visual-bell off
        set-option -g visual-silence off
        set-option -g bell-action none
        set-window-option -g monitor-activity off

        # Window behavior
        set-option -g window-size latest
        setw -g aggressive-resize on
        setw -g mode-keys vi

        # Terminal settings
        set -sa terminal-features ',xterm-256color:RGB'
        set-option -g default-terminal "tmux-256color"
        set-option -ga terminal-overrides ",*256col*:Tc"

        # Mouse and indexing
        set-option -g mouse on
        set-option -g base-index 1
        set-option -g pane-base-index 1
        set-option -g renumber-windows on

        # Disable status bar
        set-option -g status off
        set-option -g history-limit 0

        # Tokyo Night theme - Server variant
        set-option -g pane-border-style "fg=#3b4261"
        set-option -g pane-active-border-style "fg=#7aa2f7"
        set-option -g mode-style "fg=#1a1b26,bg=#e0af68"
        set-option -g message-style "fg=#c0caf5,bg=#292e42"
        set-option -g message-command-style "fg=#c0caf5,bg=#292e42"
        set-option -g popup-style "fg=#c0caf5,bg=#1a1b26"
        set-option -g popup-border-style "fg=#7aa2f7"
        set-option -g popup-border-lines "rounded"
        set-option -g menu-style "fg=#c0caf5,bg=#292e42"
        set-option -g menu-selected-style "fg=#1a1b26,bg=#7aa2f7"
        set-option -g menu-border-style "fg=#3b4261"
        set-option -g menu-border-lines "rounded"
      '';

      # Client-side tmux config (runs locally)
      tmeshTmuxConfig = ''
        # Extended keys support (CSI u / kitty keyboard protocol)
        set -s extended-keys on
        set -as terminal-features ',*:extkeys'

        # Terminal settings
        set-option -g default-terminal "tmux-256color"
        set-option -ga terminal-overrides ",*256col*:Tc"

        # Mouse and indexing
        set-option -g mouse on
        set-option -g base-index 1
        set-option -g pane-base-index 1
        set-option -g renumber-windows on

        # Clipboard and system integration
        set-option -g set-clipboard on
        set-option -g focus-events on
        set-option -s escape-time 0

        # Disable status bar
        set-option -g status off
        set-option -g history-limit 0

        # Tokyo Night theme
        set-option -g pane-border-style "fg=#3b4261"
        set-option -g pane-active-border-style "fg=#7aa2f7"
        set-option -g mode-style "fg=#1a1b26,bg=#bb9af7"
        set-option -g message-style "fg=#c0caf5,bg=#24283b"
        set-option -g message-command-style "fg=#c0caf5,bg=#24283b"
        set-option -g popup-style "fg=#c0caf5,bg=#1a1b26"
        set-option -g popup-border-style "fg=#7aa2f7"
        set-option -g popup-border-lines "rounded"
        set-option -g menu-style "fg=#c0caf5,bg=#24283b"
        set-option -g menu-selected-style "fg=#1a1b26,bg=#7aa2f7"
        set-option -g menu-border-style "fg=#3b4261"
        set-option -g menu-border-lines "rounded"
      '';
    };

    # Default shell command for tmesh sessions
    environment.sessionVariables = {
      TMESH_CMD = "nvim";
    };

    ###################
    # Mountainous
    ###################

    mountainous = {
      agenix.enable = mkDefault true;

      boot.systemd-boot = {
        timeout = 3;
        configurationLimit = 10;
      };

      impermanence = {
        enable = true;
        persistPath = "/tundra/permafrost";
      };
      user = {
        enable = mkDefault true;
        name = mkDefault "simonwjackson";
        # hashedPasswordFile = mkDefault config.age.secrets."user-simonwjackson".path;
        # authorizedKeys = let
        #   keysDir = ../../../../../keys/users;
        #   isPublicKey = name: type: type == "regular" && lib.hasSuffix ".pub" name;
        #   pubKeyFiles = lib.filterAttrs isPublicKey (builtins.readDir keysDir);
        #   keys = lib.mapAttrsToList (name: _: builtins.readFile (keysDir + "/${name}")) pubKeyFiles;
        # in
        #   keys;
      };
    };

    ###################
    # Misc
    ###################

    environment.systemPackages = [
      # WARN: Still early days for uutils
      pkgs.uutils-coreutils-noprefix
      pkgs.xh
      pkgs.dust
    ];

    mountainous.tailscale.enable = true;

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = mkDefault 1;
      "net.ipv6.conf.all.forwarding" = mkDefault 1;
      "net.ipv6.conf.all.disable_ipv6" = lib.mkForce 1;
      "net.ipv6.conf.default.disable_ipv6" = lib.mkForce 1;
    };

    networking = {
      useDHCP = lib.mkDefault true;
      domain = "mountaino.us";
      # Add .local to search so bare hostnames fall back to mDNS
      # e.g., "aka" tries aka.mountaino.us, then aka.local
      search = ["mountaino.us" "local"];
      networkmanager = {
        enable = true;
      };
    };

    # WARN: This speeds up `nixos-rebuild`, but im not sure if there are any side effects
    systemd.services.NetworkManager-wait-online.enable = false;

    users = {
      groups.media = {
        gid = lib.mkForce 333;
      };

      users.media = {
        homeMode = "770";
        group = "media";
        uid = lib.mkForce 333;
        isNormalUser = false;
      };
    };

    # Gaming configuration - available to all systems
    # Systems must set mountainous.gaming.streaming.enable and mountainous.gaming.streaming.monitor
    mountainous.gaming.steamButton.enable = false; # Disabled - using window rules instead

    mountainous.gaming.streaming.profiles = [
      # Standard resolutions
      {
        name = "4K 60";
        resolution = "3840x2160";
        refresh = 60;
        scaling = 1;
      }
      {
        name = "FHD 120";
        resolution = "1920x1080";
        refresh = 120;
        scaling = 1;
      }

      # Samsung Galaxy Z Fold 7
      {
        name = "ZFold 7 (Portrait)";
        resolution = "1968x2184";
        refresh = 90;
        scaling = 2;
      }
      {
        name = "ZFold 7 (Landscape)";
        resolution = "2184x1968";
        refresh = 90;
        scaling = 2;
      }
    ];

    # environment.pathsToLink = ["/share/zsh"];

    hardware = {
      # This means we can use firmware that is not redistributable
      enableRedistributableFirmware = true;
      enableAllFirmware = true;
    };

    # VM-specific configuration that only applies when building a VM
    virtualisation.vmVariant = {
      # These settings only apply when building with nixos-rebuild build-vm
      virtualisation = {
        memorySize = 4096; # Example: Set VM memory to 4GB
        cores = 4; # Example: Set VM cores

        qemu.options = [
          # Force auto-resize to be enabled
          "-device virtio-gpu-pci"
          "-display gtk,gl=on"
        ];
      };

      # Enable QEMU Guest Agent
      services.qemuGuest.enable = true;

      # VM-specific packages and servicesvm
      environment.systemPackages = with pkgs; [
        # Install SPICE agent and utilities
        spice-vdagent # This enables auto-resize and clipboard sharing
      ];

      # For better graphics performance (if using VirtIO)
      boot.initrd.kernelModules = ["virtio_gpu"];

      # Enable X11 auto-resize for SPICE
      services.xserver.videoDrivers = ["qxl"]; # Use "virtio" if using VirtIO graphics

      # For Wayland-based desktops like Hyprland
      hardware.opengl.enable = true;

      # A daemon that provides clipboard sharing and auto-resize
      services.spice-vdagentd.enable = true;
    };

    # Automatic timezone detection
    services.automatic-timezoned.enable = true;

    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };

    services = {
      # Enable TTY mouse
      gpm.enable = true;

      # OpenSSH server
      openssh.enable = true;

      # A daemon that automatically adjusts CPU frequency based on usage
      auto-cpufreq.enable = true;

      # Enable time synchronization
      timesyncd.enable = mkDefault true;

      # Enable avahi for local network discovery (.local hostnames)
      avahi = {
        enable = true;
        nssmdns4 = true;
        nssmdns6 = true;
        openFirewall = true;
        # Publish this host so others can find it via mDNS
        publish = {
          enable = true;
          addresses = true;
          workstation = true;
        };
      };

      # A shell daemon created to manage processes' IO and CPU priorities, with community-driven set of rules
      ananicy = {
        enable = true;
        package = pkgs.ananicy-cpp;
      };
    };

    # A compiler cache that can speed up build times
    programs.ccache.enable = true;

    security = {
      # A daemon that allows for real-time kernel parameters to be changed
      rtkit.enable = true;

      sudo = {
        wheelNeedsPassword = false;
        extraRules = [
          {
            users = ["simonwjackson"];

            commands = [
              {
                command = "ALL";
                options = ["NOPASSWD" "SETENV"];
              }
            ];
          }
        ];
      };

      # Increase open file limit for sudoers
      pam.loginLimits = [
        {
          domain = "@wheel";
          type = "-";
          item = "memlock";
          value = "unlimited";
        }
        {
          domain = "simonwjackson";
          type = "soft";
          item = "memlock";
          value = "unlimited";
        }
        {
          domain = "simonwjackson";
          type = "hard";
          item = "memlock";
          value = "unlimited";
        }
      ];
    };

    nixpkgs = {
      config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "python-2.7.18.6"
        ];
      };
    };

    nix = {
      package = pkgs.nixVersions.latest;
      # This will add each flake input as a registry
      # To make nix3 commands consistent with your flake
      registry = lib.mapAttrs (_: value: {flake = value;}) inputs;

      # This will additionally add your inputs to the system's legacy channels
      # Making legacy nix commands consistent as well, awesome!
      nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

      optimise.automatic = true;
      settings = {
        flake-registry = ""; # Disable global flake registry
        warn-dirty = false;
        # Enable flakes
        experimental-features = ["nix-command" "flakes"];
        # Add cachix binary cache
        trusted-substituters = [
          "https://nix-gaming.cachix.org"
          "https://cache.nixos.org/"
          "https://nix-community.cachix.org"
          "https://simonwjackson.cachix.org"
          "https://hyprland.cachix.org"
        ];
        trusted-users = ["root" "@wheel" "simonwjackson" "admin"];
        trusted-public-keys = [
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "simonwjackson.cachix.org-1:MtG0AE8J6bjFO/wD04X5h8MlQh7Sbee8KAJrAsPJydI="
          "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        ];
        auto-optimise-store = true;
      };

      distributedBuilds = true;
      extraOptions = ''
        builders-use-substitutes = true
        !include ${config.age.secrets."github-token-nix".path}
      '';
    };
  };
}
