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
    # ../../profiles/sound
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

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "kita"; # Define your hostname.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "simonwjackson";

  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

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

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "usbhid" "sd_mod" "sdhci_pci"];
  boot.initrd.kernelModules = [];
  boot.supportedFilesystems = ["xfs" "f2fs"];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "fbcon=rotate:1"
    "video=eDP-1:panel_orientation=right_side_up"
  ];

  services.xserver.videoDrivers = ["intel"];
  #   Option "DRI" "2"
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

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s20f0u4u3.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # services.sunshine.enable = true;
  #
  # # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;
  # services.xserver.libinput.touchpad.disableWhileTyping = true;
  # services.xserver.libinput.touchpad.tapping = true;
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
  # boot.initrd.availableKernelModules = [
  #   "xhci_pci"
  #   "thunderbolt"
  #   "nvme"
  #   "usb_storage"
  #   "usbhid"
  #   "sd_mod"
  #   # "rtsx_pci_sdmmc"
  # ];
  # boot.initrd.kernelModules = [];
  # boot.kernelModules = [
  #   "kvm-intel"
  #   "uinput"
  # ];
  # # hardware.xone.enable = true;
  # environment.systemPackages = with pkgs; [
  #   # linuxKernel.packages.linux_zen.xone
  #   nfs-utils
  #   cifs-utils
  #   acpi
  # ];
  # # boot.extraModulePackages = [
  # #   config.boot.kernelPackages.rtl88x2bu
  # #   config.boot.kernelPackages.rtl8814au
  # # ];
  #
  # boot.kernelPackages = pkgs.linuxPackages_zen;
  # # boot.kernelPackages = pkgs.linuxPackages_latest;
  # # boot.kernelPackages = pkgs.linuxPackages_6_1;
  #
  # fileSystems."/" = {
  #   device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
  #   fsType = "btrfs";
  #   options = ["subvol=root" "compress=zstd"];
  # };
  #
  # fileSystems."/home" = {
  #   device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
  #   fsType = "btrfs";
  #   options = ["subvol=home" "compress=zstd"];
  # };
  #
  # fileSystems."/glacier/snowscape" = {
  #   device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
  #   fsType = "btrfs";
  #   options = ["subvol=storage" "compress=zstd"];
  # };
  #
  # fileSystems."/nix" = {
  #   device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
  #   fsType = "btrfs";
  #   options = ["subvol=nix" "compress=zstd" "noatime"];
  # };
  #
  # fileSystems."/boot" = {
  #   device = "/dev/disk/by-uuid/D21E-0411";
  #   fsType = "vfat";
  # };
  #
  # swapDevices = [{device = "/dev/nvme0n1p2";}];
  #
  # # Includes the Wi-Fi and Bluetooth firmware
  # hardware.enableRedistributableFirmware = true;
  #
  # # hardware.opengl.enable = true;
  # hardware.nvidia.prime.offload.enable = lib.mkForce true;
  # services.xserver.videoDrivers = ["nvidia"];
  #
  # # Optionally, you may need to select the appropriate driver version for your specific GPU.
  # hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;
  #
  # hardware.bluetooth.enable = true;
  # services.blueman.enable = true;
  #
  # nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  # powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  # hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  #
  # networking.useDHCP = lib.mkDefault true;
  # # Use the systemd-boot EFI boot loader.
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  # # nix.settings.substituters = [ "https://aseipp-nix-cache.global.ssl.fastly.net" ];
  # networking.hostName = "zao"; # Define your hostname.
  #
  # # services.logind = {
  # #   # TODO: only when on battery power
  # #   extraConfig = ''
  # #     IdleAction=suspend-then-hibernate
  # #     IdleActionSec=5m
  # #     HandlePowerKey=suspend
  # #   '';
  # # };
  # # systemd.sleep.extraConfig = "HibernateDelaySec=5m";
  #
  # # Set your time zone.
  # time.timeZone = "America/Chicago";
  #
  # # Enable the X11 windowing system.
  # services.xserver.enable = true;
  #
  # # Enable the Plasma 5 Desktop Environment.
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;
  # services.xserver.displayManager.autoLogin.enable = true;
  # services.xserver.displayManager.autoLogin.user = "simonwjackson";
  #
  # # Enable sound.
  # sound.enable = true;
  # services.pipewire = {
  #   enable = true;
  #   alsa.enable = true;
  #   alsa.support32Bit = true;
  #   pulse.enable = true;
  # };
  #
  # # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.simonwjackson = {
  #   isNormalUser = true;
  #   extraGroups = ["wheel"];
  #   packages = with pkgs; [
  #     firefox
  #     git
  #     tmux
  #     neovim
  #     kitty
  #   ];
  # };
  #
  # # services.create_ap = {
  # #   enable = false;
  # #   settings = {
  # #     FREQ_BAND = 5;
  # #     HT_CAPAB = "[HT20][HT40-][HT40+][SHORT-GI-20][SHORT-GI-40][TX-STBC][MAX-AMSDU-7935][DSSS_CCK-40][PSMP]";
  # #     VHT_CAPAB = "[MAX-MPDU-11454][RXLDPC][SHORT-GI-80][TX-STBC-2BY1][RX-STBC-1][MAX-A-MPDU-LEN-EXP0]";
  # #     IEEE80211AC = true;
  # #     IEEE80211N = true;
  # #     GATEWAY = "192.18.5.1";
  # #     PASSPHRASE = "";
  # #     INTERNET_IFACE = "wlp0s20f0u3";
  # #     WIFI_IFACE = "wlp0s20f3";
  # #     SSID = "hopstop";
  # #   };
  # # };
  #
  # # networking.wlanInterfaces = {
  # #   "wlan-station0" = { device = "wlp0s2";};
  # #   "wlan-ap0"      = { device = "wlp0s2"; mac = "08:11:96:0e:08:0a"; };
  # # };
  # #
  # # networking.networkmanager.unmanaged = [ "interface-name:wlp*" ]
  # #     ++ lib.optional config.services.hostapd.enable "interface-name:${config.services.hostapd.interface}";
  # #
  # # services.hostapd = {
  # #   enable        = true;
  # #   interface     = "wlan-ap0";
  # #   hwMode        = "g";
  # #   ssid          = "nix";
  # #   wpaPassphrase = "mysekret";
  # # };
  # #
  # # services.haveged.enable = config.services.hostapd.enable;
  # #
  # # networking.interfaces."wlan-ap0".ipv4.addresses =
  # #   lib.optionals config.services.hostapd.enable [{ address = "192.168.12.1"; prefixLength = 24; }];
  #
  # # This value determines the NixOS release from which the default
  # # settings for stateful data, like file locations and database versions
  # # on your system were taken. It's perfectly fine and recommended to leave
  # # this value at the release version of the first install of this system.
  # # Before changing this value read the documentation for this option
  # # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  # system.stateVersion = "23.05"; # Did you read the comment?
  #
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
