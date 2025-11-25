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

  # Printing support
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      brlaser  # Brother laser printer driver
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

  # VPN namespace service - other services depend on this
  systemd.services.vpn-ns = {
    description = "VPN Network Namespace";
    wantedBy = [ "multi-user.target" ];
    wants = [ "transmission.service" ];  # Start transmission when vpn-ns starts
    before = [ "transmission.service" ]; # Ensure vpn-ns is ready before transmission
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.vpn-ns}/bin/vpn-ns --setup";
      ExecStop = "${pkgs.vpn-ns}/bin/vpn-ns --cleanup";
    };
    environment.VPN_NS_CONFIG = config.age.secrets."fastest-vpn".path;
  };

  # Transmission running inside VPN namespace
  services.transmission = {
    enable = true;
    package = pkgs.transmission_4;
    openFirewall = true;
    settings = {
      rpc-bind-address = "0.0.0.0";
      rpc-whitelist-enabled = false;
      rpc-host-whitelist-enabled = false;
    };
  };

  # Run transmission inside the VPN namespace
  systemd.services.transmission = {
    after = [ "vpn-ns.service" ];
    bindsTo = [ "vpn-ns.service" ];  # Stop transmission if vpn-ns stops
    partOf = [ "vpn-ns.service" ];   # Restart transmission when vpn-ns restarts
    serviceConfig = {
      NetworkNamespacePath = "/run/netns/vpn";
      BindReadOnlyPaths = [ "/etc/netns/vpn/resolv.conf:/etc/resolv.conf" ];
    };
  };

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
      transmission = {
        hostname = "transmission";
        port = 9091;
        protocol = "http";
        host = "10.200.200.2"; # VPN namespace via veth
      };
    };
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
