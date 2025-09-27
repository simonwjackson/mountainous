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
  age.secrets."tailscale" = {
    file = ../../../../secrets/agenix/tailscale.age;
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
    extraModulePackages = [];
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
    kernelModules = ["kvm-amd" "tun"];
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

  # Enable mountainous Syncthing module with auto-discovery
  mountainous.syncthing = {
    enable = true;
    # Configuration automatically discovered from ./syncthing.nix
    # Certificates automatically configured from agenix secrets
    otherDevices = {
      # Add external devices here as needed
      # Example:
      # "phone" = {
      #   id = "DEVICE-ID-HERE";
      #   shares = ["photos" "documents"];
      # };
    };
  };

  # VPN-isolated services configuration
  # mountainous.vpn-isolated-service = {
  #   enable = true;
  #
  #   namespaces = {
  #     vpn = {
  #       wireguardConfigFile = config.age.secrets."proton".path;
  #       accessibleFrom = [
  #         "192.168.0.0/16"
  #         "10.0.0.0/8"
  #         "172.16.0.0/12"
  #         "100.64.0.0/10" # Tailscale network
  #       ];
  #       portMappings = [
  #         {
  #           from = 8888;
  #           to = 8888;
  #         }
  #       ];
  #     };
  #   };
  #
  #   services = {
  #     ip-display = {
  #       vpnNamespace = "vpn";
  #       description = "Simple HTTP server displaying public IP";
  #       script = ''
  #         ${pkgs.python3}/bin/python3 ${config.mountainous.vpn-isolated-service.lib.ipDisplayScript}
  #       '';
  #     };
  #   };
  # };

  services.music-assistant.providers = ["sonos" "sonos_s1" "ytmusic" "chromecast" "filesystem_local" "filesystem_smb" "jellyfin"];
  services.music-assistant.enable = true;

  services.sabnzbd = {
    enable = true;
    openFirewall = true;
  };

  # Configure sabnzbd to listen on all interfaces
  systemd.services.sabnzbd.serviceConfig.ExecStart = lib.mkForce "${pkgs.sabnzbd}/bin/sabnzbd -d -s 0.0.0.0:8080 -f /var/lib/sabnzbd/sabnzbd.ini";

  mountainous.tsnet-proxy = {
    enable = true;
    authKeyFile = config.age.secrets."tailscale".path;
    services = {
      sabnzbd = {
        hostname = "usenet";
        port = 8080;
        protocol = "http";
        host = "127.0.0.1"; # Local sabnzbd service
      };
    };
  };

  # Enable Flatpak support
  services.flatpak.enable = true;

  # Add Flatpak directories to XDG_DATA_DIRS for desktop integration
  environment.sessionVariables = {
    XDG_DATA_DIRS = [
      "/var/lib/flatpak/exports/share"
      "/home/simonwjackson/.local/share/flatpak/exports/share"
    ];
  };

  system.stateVersion = "24.05";
}
