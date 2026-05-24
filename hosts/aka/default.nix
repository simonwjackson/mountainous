{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  korriApiPort = 3001;
  korriLibraryRoot = "/home/simonwjackson/.local/share/korri/library";
  korriStateRoot = "/home/simonwjackson/.local/state/korri";

  korriSwayStartup = pkgs.writeShellScript "korri-sway-startup" ''
    set -eu

    if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
      echo "korri-sway-startup: XDG_RUNTIME_DIR is required" >&2
      exit 1
    fi
    if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      echo "korri-sway-startup: WAYLAND_DISPLAY is required" >&2
      exit 1
    fi
    if [ -z "''${SWAYSOCK:-}" ]; then
      echo "korri-sway-startup: SWAYSOCK is required" >&2
      exit 1
    fi

    export XDG_CURRENT_DESKTOP=sway
    export XDG_SESSION_TYPE=wayland

    ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
      XDG_CURRENT_DESKTOP \
      XDG_SESSION_TYPE \
      XDG_RUNTIME_DIR \
      WAYLAND_DISPLAY \
      SWAYSOCK

    ${pkgs.systemd}/bin/systemctl --user start sunshine.service
  '';
in
{
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "aka";
  time.timeZone = "America/Denver";

  mountainous = {
    presets = {
      core.enable = true;
      desktop.enable = false;
    };

    features = {
      device = {
        role = "desktop";
        capabilities = {
          battery = false;
          formFactor = "tower";
          touchscreen = false;
        };
      };

      bluetooth.enable = true;
      gaming.enable = false;
      hyprland.enable = false;
      hibernation = {
        enable = true;
        resumeDevice = "/dev/disk/by-id/nvme-SAMSUNG_MZQLB7T6HMLA-00007_S4BGNC0R803650-part2";
        swap.mode = "partition";
      };
    };
  };

  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  networking = {
    networkmanager.enable = true;

    # Intel I225-V wired NIC. Keep wake-on-LAN independent of NetworkManager
    # profile state so the machine can be woken from suspend/hibernate/off.
    interfaces.eno1.wakeOnLan.enable = true;
  };

  powerManagement.enable = true;

  systemd.sleep.settings.Sleep = {
    AllowSuspend = true;
    AllowHibernation = true;
    AllowSuspendThenHibernate = true;
    HibernateDelaySec = "2h";
  };

  programs = {
    hyprland.enable = false;
    sway = {
      enable = true;
      xwayland.enable = true;
    };
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common = lib.mkForce {
      default = "*";
    };
  };

  # The default sway config (included below) defines a status bar. Sway's bar
  # blocks are additive and not overridable by id from outside, so we hide
  # every bar at runtime instead of forking the upstream config.
  home-manager.users.simonwjackson.xdg.configFile."sway/config".text = ''
    include ${pkgs.sway}/etc/sway/config
    exec_always ${pkgs.sway}/bin/swaymsg bar mode invisible
    exec_always ${korriSwayStartup}
  '';

  services = {
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd sway";
          user = "greeter";
        };
        initial_session = {
          command = "sway";
          user = "simonwjackson";
        };
      };
    };

    sunshine = {
      enable = true;
      openFirewall = true;
      autoStart = false;

      applications = {
        # Empty command: Sunshine's Desktop app streams the already-running
        # Sway session that starts this user service.
        apps = [
          {
            name = "Desktop (Sway)";
            image-path = "desktop.png";
          }
        ];

        env.PATH = lib.makeBinPath [
          pkgs.coreutils
          pkgs.nix
          pkgs.util-linux
        ];
      };

      settings = {
        output_name = 0;
        encoder = "vaapi";
        key_rightalt_to_key_win = "enabled";
      };
    };

    korri = {
      server = {
        enable = true;
        serviceMode = "system";
        user = "simonwjackson";
        group = "users";
        host = "0.0.0.0";
        port = korriApiPort;
        serverId = "aka";
        library.root = korriLibraryRoot;
        publicApiBaseUrl = "http://192.168.1.117:${toString korriApiPort}";
        streamControl.enable = true;
        openFirewall = true;
        advertise = {
          enable = true;
          name = "Korri Stream on aka";
        };
        streamHost = {
          enable = true;
          appName = "Korri Stream";
        };
      };

      gameStream = {
        path = [
          pkgs.coreutils
          pkgs.nix
          pkgs.util-linux
        ];
        sunshine.outputLog = "${korriStateRoot}/game-stream-runner.log";
        sway.package = pkgs.sway;
      };
    };

    logind.settings.Login = {
      HandlePowerKey = "suspend-then-hibernate";
      HandleSuspendKey = "suspend";
      HandleHibernateKey = "hibernate";
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # services.korri.server.streamHost.enable pulls in services.korri.gameStream,
  # which owns the Sunshine /dev/uinput udev defaults needed for streamed input.

  systemd.tmpfiles.settings."10-korri-game-stream" = {
    "${korriStateRoot}".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0700";
    };
  };

  environment.systemPackages = [
    pkgs.btrfs-progs
    pkgs.ethtool
  ];

  system.stateVersion = "24.11";
}
