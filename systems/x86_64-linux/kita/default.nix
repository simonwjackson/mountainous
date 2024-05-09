{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  mountainous = {
    performance.enable = true;
    profiles.laptop.enable = true;
    gaming = {
      core = {
        enable = true;
        isHost = true;
      };

      emulation.enable = true;
      steam.enable = true;
    };

    hardware.battery.enable = true;
  };

  age.secrets.kita-syncthing-key.file = ../../../secrets/kita-syncthing-key.age;
  age.secrets.kita-syncthing-cert.file = ../../../secrets/kita-syncthing-cert.age;

  services.power-profiles-daemon.enable = false;
  virtualisation.waydroid.enable = true;

  programs.xwayland.enable = true;
  programs.ccache.enable = true;

  zramSwap.enable = true;
  services.resolved.enable = true;

  programs.dconf.enable = true;

  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
  };

  xdg.portal.enable = true;

  environment.systemPackages = with pkgs; [
    undervolt
    mergerfs
    git
    moonlight-qt
    kitty
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

  fileSystems."/glacier/blizzard" = {
    device = "/dev/disk/by-uuid/899ac974-c586-4021-8509-10313660cc3f";
    fsType = "btrfs";
    options = ["subvol=blizzard" "discard=async" "compress=zstd"];
  };

  fileSystems."/glacier/sleet" = {
    device = "/dev/disk/by-label/sleet";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/nvme0n1p1";
    # device = "/dev/disk/by-uuid/12CE-A600";
    fsType = "vfat";
  };

  fileSystems."/glacier/snowscape" = {
    # depends = ["/glacier/blizzard" "/glacier/sleet"];
    depends = ["/glacier/blizzard"];
    device = "/glacier/blizzard";
    # device = "/glacier/blizzard:/glacier/sleet";
    fsType = "fuse.mergerfs";
    options = [
      "minfreespace=1G"
      "category.create=ff"
      "category.search=ff"
      "attr_timeout=60"
      "ignorepponrename=true"
      "moveonenospc=true"
    ];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-uuid/3873bb31-f29c-4a3b-98f9-10f2334c55a8";
    }
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # networking.hostName = "kita";

  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = config.mountainous.user.name;
  services.xserver.desktopManager.plasma5.enable = true;
  services.xserver.displayManager.defaultSession = "plasmawayland";
  services.xserver.displayManager.sddm.wayland.enable = true;

  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = [
      "adbusers"
      "audio"
      "input"
      "libvirtd"
      "lp"
      "networkmanager"
      "scanner"
      "video"
      "wheel"
    ];
    packages = with pkgs; [
      firefox
      neovim
      git
      tmux
      mosh
    ];
  };

  services.openssh.enable = true;
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    sensor.iio.enable = true;
    opengl = {
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        rocm-opencl-icd
        vaapiVdpau
        rocm-opencl-runtime
        libvdpau-va-gl
      ];
    };
    enableAllFirmware = true;
    bluetooth = {enable = true;};
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    steam-hardware.enable = true;
  };

  services.geoclue2.enable = true;

  powerManagement.powertop.enable = true;

  # services.logind.lidSwitch = "suspend-then-hibernate";
  # services.logind.lidSwitchExternalPower = "suspend";
  #
  # services.logind.extraConfig = ''
  #   HandlePowerKey=suspend-then-hibernate
  #   HandleSuspendKey=suspend-then-hibernate
  #   HandleHibernateKey=suspend-then-hibernate
  # '';
  #
  # systemd.sleep.extraConfig = "HibernateDelaySec=5m";

  services.syncthing = {
    enable = true;
    key = config.age.secrets.kita-syncthing-key.path;
    cert = config.age.secrets.kita-syncthing-cert.path;
  };

  system.stateVersion = "23.11"; # Did you read the comment?
}
#   # services.logind = {
#   #   # TODO: only when on battery power
#   #   extraConfig = ''
#   #     IdleAction=suspend-then-hibernate
#   #     IdleActionSec=5m
#   #   '';
#   # };
#
#   # # services.syncthing = {
#   # #   dataDir = "/home/simonwjackson"; # Default folder for new synced folders
#   # #
#   # #   folders = {
#   # #     code.path = "/home/simonwjackson/code";
#   # #     documents.path = "/glacier/snowscape/documents";
#   # #     gaming-games.path = "/glacier/snowscape/gaming/games";
#   # #     gaming-launchers.path = "/glacier/snowscape/gaming/launchers";
#   # #     gaming-profiles.path = "/glacier/snowscape/gaming/profiles";
#   # #     gaming-systems.path = "/glacier/snowscape/gaming/systems";
#   # #     taskwarrior.path = "/home/simonwjackson/.local/share/task";
#   # #
#   # #     code.devices = [ "fiji" "unzen" "yari" ];
#   # #     documents.devices = [ "fiji" "unzen" "zao" ];
#   # #     gaming-games.devices = [ "fiji" "unzen" "yari" "zao" ];
#   # #     gaming-launchers.devices = [ "fiji" "unzen" "zao" ];
#   # #     gaming-profiles.devices = [ "fiji" "usu" "unzen" "yari" "zao" ];
#   # #     gaming-systems.devices = [ "fiji" "unzen" "zao" ];
#   # #     taskwarrior.devices = [ "fiji" "unzen" "zao" ];
#   # #
#   # #     gaming-profiles.versioning = {
#   # #       type = "staggered";
#   # #       params = {
#   # #         cleanInterval = "3600";
#   # #         maxAge = "31536000";
#   # #       };
#   # #     };
#   # #   };
#   # # };
# }

