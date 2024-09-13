{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}: let
  inherit (lib.backpacker) enabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  services.autofs = {
    enable = true;
    autoMaster = let
      akaConf = pkgs.writeText "auto.aka" ''
        snowscape -fstype=nfs,rw,sync,soft,intr,noresvport,timeo=30,retrans=10,retry=0 aka:/snowscape
      '';
      kitaConf = pkgs.writeText "auto.kita" ''
        snowscape -fstype=nfs,rw,sync,soft,intr,noresvport,timeo=30,retrans=10,retry=0 kita:/snowscape
      '';
    in ''
      /nfs/aka ${akaConf}
      /nfs/kita ${kitaConf}
    '';
  };

  environment.systemPackages = [pkgs.nfs-utils pkgs.mergerfs];
  services.rpcbind.enable = true;

  services.nfs.server = {
    enable = true;
    exports = ''
      /snowscape 192.168.1.0/24(rw,sync,no_subtree_check) \
                 100.64.0.0/10(rw,sync,no_subtree_check) \
                 172.16.0.0/12(rw,sync,no_subtree_check)
    '';
  };

  services.syncthing-auto-pause = {
    enable = true;
    managedShares = ["games"];
  };

  backpacker = {
    performance = enabled;
    gaming = {
      core = enabled;
      sunshine.enable = true;
      emulation = {
        enable = true;
        gen-7 = true;
        gen-8 = true;
        gamingDir = "/snowscape/gaming";
        saves = "/snowscape/gaming/profiles/simonwjackson/progress/saves";
      };
      steam = enabled;
    };
    networking.core.names = [
      {
        name = "wifi";
        mac = "e4:60:17:d1:e6:d8";
      }
    ];
    profiles.laptop = enabled;
    syncthing = {
      key = config.age.secrets.kita-syncthing-key.path;
      cert = config.age.secrets.kita-syncthing-cert.path;
    };
    waydriod = enabled;
    hardware = {
      bluetooth = enabled;
    };
    desktops.plasma = enabled;
    desktops.hyprland = enabled;
  };

  mountainous = {
    hardware = {
      devices.gpd-win-mini = enabled;
    };
  };

  fileSystems."/snowscape" = {
    device = "/storage/blizzard:/storage/sleet";
    fsType = "fuse.mergerfs";
    options = [
      "minfreespace=4G"
      "use_ino"
      "cache.files=partial"
      "dropcacheonclose=true"
      "allow_other"
      "category.create=ff"
      "fsname=snowscape"
      "nonempty"
      "defaults"
      "allow_other"
      # "nofail"
    ];
  };

  fileSystems."/storage/sleet" = {
    device = "/dev/disk/by-label/sleet";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/5067-7886";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-uuid/3873bb31-f29c-4a3b-98f9-10f2334c55a8";
    }
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=root" "discard=async" "compress=zstd"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=home" "discard=async" "compress=zstd"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=nix" "compress=zstd" "discard=async" "noatime"];
  };

  fileSystems."/storage/blizzard" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=blizzard" "discard=async" "compress=zstd"];
  };

  # WARN: Do not change this unless reinstalling
  system.stateVersion = "23.11";
}
