{lib, ...}: {
  imports = [
    ./hardware.nix
  ];

  networking.hostName = "zao";
  time.timeZone = "America/Denver";

  nixpkgs.config.allowUnfree = true;

  # Temporary placeholder so the host can evaluate before we decide on the
  # actual disk layout for nixos-anywhere.
  fileSystems."/" = lib.mkDefault {
    device = "none";
    fsType = "tmpfs";
  };

  mountainous.features.device = {
    role = "portable";
    capabilities = {
      battery = true;
      formFactor = "laptop";
      touchscreen = false;
    };
  };

  # Minimal bootstrap scaffolding to satisfy the repo-wide host defaults while
  # we intentionally keep this host otherwise hardware-focused for now.
  services.openssh.enable = true;

  users.groups.simonwjackson = {};
  users.users.simonwjackson = {
    isNormalUser = true;
    group = "simonwjackson";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ];
  };

  security.tpm2.enable = lib.mkDefault true;

  hardware = {
    enableRedistributableFirmware = lib.mkDefault true;
    i2c.enable = lib.mkDefault true;
    nvidia = {
      modesetting.enable = true;
      open = false;
      powerManagement.enable = lib.mkDefault true;
      prime = {
        offload.enable = true;
        offload.enableOffloadCmd = true;
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };

  services = {
    fwupd.enable = lib.mkDefault true;
    thermald.enable = lib.mkDefault true;
    hardware.bolt.enable = lib.mkDefault true;
    xserver.videoDrivers = ["nvidia"];
  };

  system.stateVersion = "26.05";
}
