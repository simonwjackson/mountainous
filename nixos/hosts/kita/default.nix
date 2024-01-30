{
  config,
  pkgs,
  inputs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # ../../profiles/global
    ../../profiles/sound
    # ../../profiles/systemd-boot.nix
    # ../../users/simonwjackson
    # # ../../modules/syncthing.nix
    # ../../profiles/gaming/gaming-host.nix
    # ../../profiles/gaming/gaming.nix
  ];

  nixpkgs.config.allowUnfree = true;
  programs.gamescope.enable = true;
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    package = pkgs.steam.override {
      extraPkgs = pkgs:
        with pkgs; [
          gamescope
          mangohud
        ];
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "kita"; # Define your hostname.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "simonwjackson";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    packages = with pkgs; [
      firefox
      mangohud
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    undervolt
    mergerfs
    neovim
    git
    moonlight-qt
    kitty
    (retroarch.override {
      cores = with libretro; [
        genesis-plus-gx
        snes9x
        mgba
        nestopia
      ];
    })
  ];

  services.openssh.enable = true;
  system.stateVersion = "24.05"; # Did you read the comment?

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "usbhid" "sd_mod" "sdhci_pci"];
  boot.initrd.kernelModules = [];
  boot.supportedFilesystems = ["xfs" "f2fs"];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];
  boot.kernelPackages = pkgs.linuxPackages_6_1;
  boot.kernelParams = [
    "fbcon=rotate:1"
    "video=eDP-1:panel_orientation=right_side_up"
  ];

  services.xserver.videoDrivers = ["intel"];
  services.xserver.deviceSection = ''
    Option "TearFree" "true"
  '';

  services.tlp.enable =
    lib.mkDefault ((lib.versionOlder (lib.versions.majorMinor lib.version) "21.05")
      || !config.services.power-profiles-daemon.enable);

  # Required for grub to properly display the boot menu.
  boot.loader.grub.gfxmodeEfi = lib.mkDefault "720x1280x32";

  fileSystems."/glacier/snowscape" = {
    depends = ["/glacier/blizzard" "/glacier/sleet"];
    device = "/glacier/blizzard:/glacier/sleet";
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

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/58221615-c1fa-4808-921f-7de1fd451dba";
    fsType = "btrfs";
    options = ["subvol=root" "compress=zstd"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/58221615-c1fa-4808-921f-7de1fd451dba";
    fsType = "btrfs";
    options = ["subvol=home" "compress=zstd"];
  };

  fileSystems."/glacier/blizzard" = {
    device = "/dev/disk/by-uuid/58221615-c1fa-4808-921f-7de1fd451dba";
    fsType = "btrfs";
    options = ["subvol=blizzard" "compress=zstd"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/58221615-c1fa-4808-921f-7de1fd451dba";
    fsType = "btrfs";
    options = ["subvol=nix" "compress=zstd" "noatime"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/12CE-A600";
    fsType = "vfat";
  };

  fileSystems."/glacier/sleet" = {
    device = "/dev/mmcblk0";
    fsType = "f2fs";
    # options = ["nofail" "uid=1000" "gid=1000"];
  };

  swapDevices = [
    {
      device = "/dev/sda2";
    }
  ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # hardware.bluetooth.enable = true;

  # services.sunshine.enable = true;

  # services.xserver.libinput.enable = true;
  # services.xserver.libinput.touchpad.disableWhileTyping = true;
  # services.xserver.libinput.touchpad.tapping = true;
  #
  # services.geoclue2.enable = true;
  #
  # powerManagement.enable = true;
  # powerManagement.powertop.enable = true;
  #
  # services.logind.lidSwitch = "suspend-then-hibernate";
  # services.logind.lidSwitchExternalPower = "suspend";
  #
  # services.logind.extraConfig = ''
  #   HandlePowerKey=suspend-then-hibernate
  #   HandleSuspendKey=suspend-then-hibernate
  #   HandleHibernateKey=suspend-then-hibernate
  # '';
  #
  systemd.sleep.extraConfig = "HibernateDelaySec=5m";

  # services.logind = {
  #   # TODO: only when on battery power
  #   extraConfig = ''
  #     IdleAction=suspend-then-hibernate
  #     IdleActionSec=5m
  #   '';
  # };

  # # services.syncthing = {
  # #   dataDir = "/home/simonwjackson"; # Default folder for new synced folders
  # #
  # #   folders = {
  # #     code.path = "/home/simonwjackson/code";
  # #     documents.path = "/glacier/snowscape/documents";
  # #     gaming-games.path = "/glacier/snowscape/gaming/games";
  # #     gaming-launchers.path = "/glacier/snowscape/gaming/launchers";
  # #     gaming-profiles.path = "/glacier/snowscape/gaming/profiles";
  # #     gaming-systems.path = "/glacier/snowscape/gaming/systems";
  # #     taskwarrior.path = "/home/simonwjackson/.local/share/task";
  # #
  # #     code.devices = [ "fiji" "unzen" "yari" ];
  # #     documents.devices = [ "fiji" "unzen" "zao" ];
  # #     gaming-games.devices = [ "fiji" "unzen" "yari" "zao" ];
  # #     gaming-launchers.devices = [ "fiji" "unzen" "zao" ];
  # #     gaming-profiles.devices = [ "fiji" "usu" "unzen" "yari" "zao" ];
  # #     gaming-systems.devices = [ "fiji" "unzen" "zao" ];
  # #     taskwarrior.devices = [ "fiji" "unzen" "zao" ];
  # #
  # #     gaming-profiles.versioning = {
  # #       type = "staggered";
  # #       params = {
  # #         cleanInterval = "3600";
  # #         maxAge = "31536000";
  # #       };
  # #     };
  # #   };
  # # };
}
