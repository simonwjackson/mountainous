{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./sunshine.nix
    # ./web-app.nix
    ./disko.nix
  ];

  ################
  # STEAM
  ################

  # Use the new mountainous Steam module for proper runtime support
  mountainous.steam = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    mergerfs
    mpvScripts.uosc
    mpv
    git
    ex
    ryzenadj
    obsidian
    wireguard-tools
    whisper-cpp # For remote dictation transcription
  ];

  #######################
  # Disable onboard audio
  #######################

  boot.blacklistedKernelModules = ["snd_hda_intel"];
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", ATTR{idProduct}=="1a5c", ATTR{authorized}="0"
  '';

  # Enable WireGuard support
  networking.wireguard.enable = true;

  # Configure agenix secrets
  age.secrets."tailscale-tsnet" = {
    file = ../../../../secrets/agenix/tailscale-ephemeral.age;
    owner = "tsnet-proxy";
    group = "tsnet-proxy";
    mode = "400";
  };

  age.secrets."proton" = {
    file = ../../../../secrets/agenix/proton.age;
    owner = "root";
    group = "root";
    mode = "400";
  };

  mountainous = {
    iceberg-array.enable = true;
    impermanence.enable = lib.mkForce false;
    profiles = {
      base.enable = true;
      workspace.enable = true;
      gaming.enable = true;
    };

    # VPN isolation for services

    # networking.core.names = [
    #   {
    #     name = "wifi";
    #     mac = "fc:b0:de:7e:9f:5d";
    #   }
    #   {
    #     name = "eth";
    #     mac = "10:7c:61:4d:e4:11";
    #   }
    # ];
  };

  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };

  programs.mosh.enable = true;

  # Enable Thunderbolt support
  services.hardware.bolt.enable = true;

  # Printing support
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      brlaser # Brother laser printer driver
      gutenprint
      gutenprintBin
    ];
  };

  # Enable printer discovery and auto-configuration
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  hardware = {
    cpu = {
      amd = {
        updateMicrocode = true;
        ryzen-smu.enable = true;
      };
    };

    graphics = {
      enable = true;
      enable32Bit = true;
      # Steam module handles graphics packages
    };

    # Enable Bluetooth support
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
  };

  environment.etc."mdadm.conf".text = ''
    MAILADDR root@localhost
    PROGRAM /run/current-system/sw/bin/mdadm-monitor
  '';

  boot = {
    swraid.enable = true;
    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback
    ];
    extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=10 card_label="OBS Virtual Camera" exclusive_caps=1
    '';
    initrd = {
      availableKernelModules = [
        "ahci"
        "nvme"
        "sd_mod"
        "uas"
        "usb_storage"
        "usbhid"
        "xhci_pci"
      ];
      kernelModules = ["dm-snapshot" "amdgpu" "i2c-dev"];
    };
    kernelModules = ["kvm-amd" "tun" "v4l2loopback"];
    kernelPackages = pkgs.linuxPackages_zen;
    loader = {
      efi = {
        canTouchEfiVariables = false;
        efiSysMountPoint = "/boot";
      };
      grub = {
        enable = true;
        devices = [
          "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0374219080022724-0:0"
          "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_0374219080022992-0:0"
        ];
        efiSupport = true;
        efiInstallAsRemovable = true;
        copyKernels = true;
        fsIdentifier = "uuid";
      };
    };
  };

  ##########################################################

  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  services.xserver.enable = true;
  services.xserver.videoDrivers = ["amdgpu"];

  ###################
  # Misc
  ###################

  fileSystems."/tundra/sleet" = {
    device = "/dev/disk/by-id/usb-Generic_MassStorageClass_000000002958-0:0-part1";
    fsType = "f2fs";
    options = ["noatime" "nofail" "x-systemd.automount" "x-systemd.device-timeout=5"];
  };

  # Custom hosts file entries
  networking.hosts = {
    "127.0.0.1" = ["amazesql01.database.windows.net"];
  };

  # Base service configurations
  mountainous.transmission.enable = true;
  mountainous.sabnzbd = {
    enable = true;
    hostWhitelist = ["usenet.hummingbird-lake.ts.net"];
  };

  # VPN namespace - services register here
  mountainous.vpn-ns = {
    enable = true;
    configFile = config.age.secrets."fastest-vpn".path;
    tailscaleDomain = "hummingbird-lake.ts.net";
    services = {
      transmission = {
        enable = true;
        port = 9091;
        tailscale.enable = true;
      };
      sabnzbd = {
        enable = true;
        port = 8080;
        tailscale = {
          enable = true;
          hostname = "usenet";
        };
      };
    };
  };

  mountainous.tsnet-proxy = {
    enable = true;
    authKeyFile = config.age.secrets."tailscale-tsnet".path;
  };

  # Enable Flatpak support
  services.flatpak.enable = true;

  # Add Flatpak directories to XDG_DATA_DIRS for desktop integration
  environment.sessionVariables = {
    XDG_DATA_DIRS = [
      "/var/lib/flatpak/exports/share"
      "${config.users.users.simonwjackson.home}/.local/share/flatpak/exports/share"
    ];
  };

  system.stateVersion = "24.05";
}
