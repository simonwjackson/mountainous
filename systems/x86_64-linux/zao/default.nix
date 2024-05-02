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
  ];

  # INFO: moved from imports
  boot.loader = {
    systemd-boot = {
      enable = true;
      consoleMode = "max";
    };

    efi.canTouchEfiVariables = true;
  };
  # INFO: end

  mountainous = {
    gaming = {
      core = {
        enable = true;
        isHost = true;
      };

      emulation.enable = true;
      steam.enable = true;
    };

    battery.enable = true;
    performance.enable = true;
  };

  age.secrets.zao-syncthing-key.file = ../../../secrets/zao-syncthing-key.age;
  age.secrets.zao-syncthing-cert.file = ../../../secrets/zao-syncthing-cert.age;

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;
  services.xserver.libinput.touchpad.disableWhileTyping = true;
  services.xserver.libinput.touchpad.tapping = true;
  services.geoclue2.enable = true;

  services.logind.lidSwitch = "suspend-then-hibernate";
  services.logind.lidSwitchExternalPower = "suspend";

  services.logind.extraConfig = ''
    HandlePowerKey=suspend-then-hibernate
    HandleSuspendKey=suspend-then-hibernate
    HandleHibernateKey=suspend-then-hibernate
  '';

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [
    "kvm-intel"
    "uinput"
  ];

  environment.systemPackages = with pkgs; [
    nfs-utils
    cifs-utils
    acpi
  ];

  boot.kernelPackages = pkgs.linuxPackages_zen;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
    fsType = "btrfs";
    options = ["subvol=root" "compress=zstd"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
    fsType = "btrfs";
    options = ["subvol=home" "compress=zstd"];
  };

  fileSystems."/glacier/snowscape" = {
    device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
    fsType = "btrfs";
    options = ["subvol=storage" "compress=zstd"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/015bf7c2-0912-4d69-8e08-8e18d1ac287a";
    fsType = "btrfs";
    options = ["subvol=nix" "compress=zstd" "noatime"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/D21E-0411";
    fsType = "vfat";
  };

  swapDevices = [{device = "/dev/nvme0n1p2";}];

  # Includes the Wi-Fi and Bluetooth firmware
  hardware.enableRedistributableFirmware = true;

  # hardware.opengl.enable = true;
  hardware.nvidia.prime = {
    offload.enable = lib.mkForce true;
    nvidiaBusId = "PCI:1:0:0";
    intelBusId = "PCI:0:2:0";
  };
  services.xserver.videoDrivers = ["nvidia"];

  # Optionally, you may need to select the appropriate driver version for your specific GPU.
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  networking.useDHCP = lib.mkDefault true;
  # Use the systemd-boot EFI boot loader.
  # nix.settings.substituters = [ "https://aseipp-nix-cache.global.ssl.fastly.net" ];
  networking.hostName = "zao"; # Define your hostname.

  # services.logind = {
  #   # TODO: only when on battery power
  #   extraConfig = ''
  #     IdleAction=suspend-then-hibernate
  #     IdleActionSec=5m
  #     HandlePowerKey=suspend
  #   '';
  # };
  # systemd.sleep.extraConfig = "HibernateDelaySec=5m";

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the Plasma 5 Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "simonwjackson";

  # Enable sound.
  sound.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    packages = with pkgs; [
      firefox
      git
      tmux
      neovim
      kitty
    ];
  };

  # services.create_ap = {
  #   enable = false;
  #   settings = {
  #     FREQ_BAND = 5;
  #     HT_CAPAB = "[HT20][HT40-][HT40+][SHORT-GI-20][SHORT-GI-40][TX-STBC][MAX-AMSDU-7935][DSSS_CCK-40][PSMP]";
  #     VHT_CAPAB = "[MAX-MPDU-11454][RXLDPC][SHORT-GI-80][TX-STBC-2BY1][RX-STBC-1][MAX-A-MPDU-LEN-EXP0]";
  #     IEEE80211AC = true;
  #     IEEE80211N = true;
  #     GATEWAY = "192.18.5.1";
  #     PASSPHRASE = "";
  #     INTERNET_IFACE = "wlp0s20f0u3";
  #     WIFI_IFACE = "wlp0s20f3";
  #     SSID = "hopstop";
  #   };
  # };

  # networking.wlanInterfaces = {
  #   "wlan-station0" = { device = "wlp0s2";};
  #   "wlan-ap0"      = { device = "wlp0s2"; mac = "08:11:96:0e:08:0a"; };
  # };
  #
  # networking.networkmanager.unmanaged = [ "interface-name:wlp*" ]
  #     ++ lib.optional config.services.hostapd.enable "interface-name:${config.services.hostapd.interface}";
  #
  # services.hostapd = {
  #   enable        = true;
  #   interface     = "wlan-ap0";
  #   hwMode        = "g";
  #   ssid          = "nix";
  #   wpaPassphrase = "mysekret";
  # };
  #
  # services.haveged.enable = config.services.hostapd.enable;
  #
  # networking.interfaces."wlan-ap0".ipv4.addresses =
  #   lib.optionals config.services.hostapd.enable [{ address = "192.168.12.1"; prefixLength = 24; }];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

  services.syncthing = {
    enable = true;
    # key = config.age.secrets.fiji-syncthing-key.path;
    # cert = config.age.secrets.fiji-syncthing-cert.path;
    #
    settings.paths = {
      notes = "/glacier/snowscape/notes";
      gaming-profiles = "/glacier/snowscape/gaming/profiles";
    };
  };

  # services.syncthing = {
  #   dataDir = "/home/simonwjackson"; # Default folder for new synced folders
  #
  #   folders = {
  #     code.path = "/home/simonwjackson/code";
  #     documents.path = "/glacier/snowscape/documents";
  #     gaming-games.path = "/glacier/snowscape/gaming/games";
  #     gaming-launchers.path = "/glacier/snowscape/gaming/launchers";
  #     gaming-profiles.path = "/glacier/snowscape/gaming/profiles";
  #     gaming-systems.path = "/glacier/snowscape/gaming/systems";
  #     taskwarrior.path = "/home/simonwjackson/.local/share/task";
  #
  #     code.devices = [ "fiji" "unzen" "yari" ];
  #     documents.devices = [ "fiji" "unzen" "zao" ];
  #     gaming-games.devices = [ "fiji" "unzen" "yari" "zao" ];
  #     gaming-launchers.devices = [ "fiji" "unzen" "zao" ];
  #     gaming-profiles.devices = [ "fiji" "usu" "unzen" "yari" "zao" ];
  #     gaming-systems.devices = [ "fiji" "unzen" "zao" ];
  #     taskwarrior.devices = [ "fiji" "unzen" "zao" ];
  #
  #     gaming-profiles.versioning = {
  #       type = "staggered";
  #       params = {
  #         cleanInterval = "3600";
  #         maxAge = "31536000";
  #       };
  #     };
  #   };
  # };
}
