{
  modulesPath,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.mountainous) enabled disabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
  ];

  boot = {
    kernelParams = [
      # Set resolution at EFI level
      "video=efifb:2880x1800" # Match your native resolution
      "video=efifb:scale" # HiDPI scaling

      # Force early framebuffer setup
      "fbcon=nodefer"
      "i915.fastboot=1"
      "i915.force_probe=all" # Force early i915 initialization

      # plymouth
      "quiet" # Reduce boot messages
      "splash" # Enable splash screen
    ];

    plymouth = {
      enable = true;
      theme = "spinner";
      logo = ../../../public/mountainous-tiny.png;
    };

    # Enable early console setup
    initrd.kernelModules = ["i915"]; # Load i915 in initrd
    earlyVconsoleSetup = true;
  };

  console = {
    earlySetup = true;
  };

  mountainous = {
    impermanence = enabled;
    boot = enabled;
    snowscape = {
      enable = true;
      glacier = "unzen";
      paths = [
        "/avalanche/volumes/blizzard"
        "/avalanche/disks/sleet/0/00"
      ];
    };
    networking = {
      tailscaled.enable = lib.mkForce false;
      core.names = [
        {
          name = "wifi";
          mac = "d4:d8:53:90:2b:6c";
        }
      ];
    };
    performance = enabled;
    profiles = {
      laptop = enabled;
      workspace = disabled;
    };
    syncthing = {
      key = config.age.secrets.fuji-syncthing-key.path;
      cert = config.age.secrets.fuji-syncthing-cert.path;
    };
    hardware.devices.samsung-galaxy-book3-360 = enabled;
    desktops = {
      hyprland = {
        enable = true;
        autoLogin = true;
      };
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.luks.devices."crypted" = lib.mkForce {
    device = "/dev/disk/by-uuid/b688fe42-16eb-49f7-a9c9-c3a4210288e1";
    preLVM = true;
    allowDiscards = true;
  };
  boot.kernelPackages = pkgs.linuxPackages_6_6;

  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets."tailscale".path;
  };

  networking.firewall = {
    enable = true;
    allowedTCPPortRanges = [
      {
        from = 1;
        to = 65535;
      }
    ];
    allowedUDPPortRanges = [
      {
        from = 1;
        to = 65535;
      }
    ];

    allowPing = true;
    trustedInterfaces = lib.mkAfter ["tailscale0"];
    allowedUDPPorts = [config.services.tailscale.port];
  };

  # TODO: find a system to better manage these
  age.secrets.bluetooth-fuji-sony-ote = {
    path = lib.mkForce "/var/lib/bluetooth/D4:D8:53:90:2B:70/CC:98:8B:93:2A:1F/info";
    owner = lib.mkForce "root";
    group = lib.mkForce "root";
    mode = lib.mkForce "0600";
  };

  home-manager.backupFileExtension = "bak";
  services.playerctld = enabled;

  system.stateVersion = "24.11";
}
