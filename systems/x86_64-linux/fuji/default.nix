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

  mountainous = {
    boot = enabled;
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

  # Impermanence configuration
  programs.fuse.userAllowOther = true;

  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = ["defaults" "size=2G" "mode=755"];
    };
    "/persist".neededForBoot = true;
    "/etc/ssh".neededForBoot = true;
    "/nix".neededForBoot = true;
    "/boot".neededForBoot = true;
    "/home".neededForBoot = true;
    "/var/log".neededForBoot = true;
  };

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

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/etc/ssh"
      "/var/lib/systemd/coredump"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/tailscale"
    ];
    files = [
      "/etc/machine-id"
      "/etc/adjtime"
    ];
    users.simonwjackson = {
      directories = [
        ".ssh"
        ".gnupg"
        ".mozilla"
        ".config"
      ];
    };
  };

  fileSystems."/snowscape" = {
    device = "/avalanche/pools/snowscape";
    options = ["bind"];
  };

  fileSystems."/avalanche/pools/snowscape" = {
    device = "/avalanche/volumes/blizzard/snowscape:/avalanche/disks/sleet/0/00/snowscape";
    fsType = "fuse.mergerfs";
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "cache.files=partial"
      "dropcacheonclose=true"
      "category.create=epff" # Will write to first path (blizzard) by default
      "category.search=ff"
      "moveonenospc=true"
      "fsname=pools-snowscape"
      "posix_acl=true"
      "atomic_o_trunc=true"
      "big_writes=true"
      "auto_cache=true"
      "cache.symlinks=true"
      "cache.readdir=true"
    ];
    noCheck = true;
  };

  systemd.services.prepare-snowscape-dirs = {
    description = "Prepare directories for snowscape pool";
    after = [
      "avalanche-volumes-blizzard.mount"
      "avalanche-disks-sleet-0-00.mount"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /avalanche/volumes/blizzard/snowscape
      mkdir -p /avalanche/disks/sleet/0/00/snowscape
      chmod 2775 /avalanche/volumes/blizzard/snowscape
      chmod 2775 /avalanche/disks/sleet/0/00/snowscape
      chown media:media /avalanche/volumes/blizzard/snowscape
      chown media:media /avalanche/disks/sleet/0/00/snowscape
    '';
  };

  fileSystems."/glacier" = {
    device = "/avalanche/pools/glacier";
    options = ["bind"];
  };

  fileSystems."/avalanche/pools/glacier" = {
    device = "/net/fuji/nfs/snowscape:/net/unzen/nfs/snowscape";
    fsType = "fuse.mergerfs";
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "cache.files=partial"
      "dropcacheonclose=true"
      "category.create=epff"
      "category.search=ff" # First Found - faster searching
      "moveonenospc=true"
      "minfreespace=256M"
      "fsname=pools-glacier"
      # Network optimizations
      "posix_acl=true"
      "atomic_o_trunc=true"
      "big_writes=true"
      "auto_cache=true"
      "cache.symlinks=true" # Cache symlinks for better performance
      "cache.readdir=true" # Cache directory entries
    ];
    noCheck = true;
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

  services.udev.extraRules = ''
    SUBSYSTEM=="backlight", ACTION=="add", KERNEL=="intel_backlight", GROUP="video", MODE="0660"
  '';

  system.stateVersion = "24.11";
}
