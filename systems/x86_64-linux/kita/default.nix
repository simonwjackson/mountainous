{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}: let
  inherit (lib.mountainous) enabled;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  mountainous = {
    desktop.plasma = enabled;
    hardware.devices.gpd-win-mini = enabled;
    performance = enabled;
    profiles.laptop = enabled;
    gaming = {
      core = enabled;
      emulation = enabled;
      steam = enabled;
    };
  };

  age.secrets.kita-syncthing-key.file = ../../../secrets/kita-syncthing-key.age;
  age.secrets.kita-syncthing-cert.file = ../../../secrets/kita-syncthing-cert.age;

  services.power-profiles-daemon = enabled;
  virtualisation.waydroid = enabled;
  programs.ccache = enabled;
  zramSwap = enabled;
  services.resolved = enabled;
  programs.dconf = enabled;

  fileSystems."/glacier/blizzard" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=blizzard" "discard=async" "compress=zstd"];
  };

  fileSystems."/glacier/sleet" = {
    device = "/dev/disk/by-label/sleet";
    fsType = "ext4";
  };

  # HACK: mergerfs mount appears to be broken
  fileSystems."/glacier/snowscape" = {
    device = "/glacier/blizzard";
    options = ["bind"];
  };

  # fileSystems."/glacier/snowscape" = {
  #   # depends = ["/glacier/blizzard" "/glacier/sleet"];
  #   depends = ["/glacier/blizzard"];
  #   device = "/glacier/blizzard";
  #   # device = "/glacier/blizzard:/glacier/sleet";
  #   fsType = "fuse.mergerfs";
  #   options = [
  #     "minfreespace=1G"
  #     "category.create=ff"
  #     "category.search=ff"
  #     "attr_timeout=60"
  #     "ignorepponrename=true"
  #     "moveonenospc=true"
  #   ];
  # };

  swapDevices = [
    {
      device = "/dev/disk/by-uuid/3873bb31-f29c-4a3b-98f9-10f2334c55a8";
    }
  ];

  services.syncthing = {
    enable = true;
    key = config.age.secrets.kita-syncthing-key.path;
    cert = config.age.secrets.kita-syncthing-cert.path;
  };

  ################################################################################################

  # services.xserver.enable = true;
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;

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

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/5067-7886";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  system.stateVersion = "23.11"; # Did you read the comment?
}
