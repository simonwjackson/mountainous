{
  config,
  inputs,
  lib,
  modulesPath,
  pkgs,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # ./web-app.nix
    ./disko.nix
  ];

  ################
  # GAMING
  ################

  # Use the unified gaming feature for gaming support and streaming
  mountainous.gaming = {
    enable = true;
    citron = {
      enable = true;
      keys = inputs.switch-prod-keys;
      savePath = "/snowscape/gaming/profiles/simonwjackson/progress/saves/nintendo-switch";
      gameDirectories = ["/snowscape/gaming/games/nintendo-switch"];
      graphics = {
        backend = "vulkan"; # AMD RX 7900
        resolution = 4;
        scalingFilter = "fsr";
      };
    };
    streaming = {
      enable = true;
      monitor = "HDMI-A-2";
      monitorIndex = 2; # From hyprctl: Monitor HDMI-A-2 (ID 2)
      disableOtherMonitors = true; # DPMS off DP-1/DP-2 during streaming
    };
  };

  ################
  # DEVICE
  ################

  # Desktop gaming PC with dual high-refresh monitors
  mountainous.device = {
    role = "desktop";
    capabilities = {
      battery = false;
      touchscreen = false;
      formFactor = "tower";
    };
  };

  environment.systemPackages = with pkgs; [
    mergerfs
    git
    ex
    ryzenadj
    obsidian
    wireguard-tools
    whisper-cpp # For remote dictation transcription
    sillytavern # AI Dungeon-style LLM frontend
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

  # Override ownership for tsnet-proxy (file auto-discovered)
  age.secrets."tailscale-ephemeral" = {
    owner = "tsnet-proxy";
    group = "tsnet-proxy";
  };
  # proton secret auto-discovered with root:root defaults

  mountainous = {
    impermanence.enable = lib.mkForce false;
    profiles = {
      base.enable = true;
      workspace.enable = true;
    };

    # NFS server - export Steam library for remote access
    nfs-server = {
      enable = true;
      exports = [
        {
          path = "/snowscape/gaming/games/steam";
          clients = "*"; # Allow all - network security handled by Tailscale/firewall
          options = ["rw" "sync" "no_subtree_check" "all_squash" "anonuid=1000" "anongid=100"];
        }
      ];
    };

    # Syncthing for knowledge sync
    syncthing = {
      enable = true;
      deviceId = "DIVKBPA-VNVTEK5-FH7C2SB-QCSK6ZC-N4OE7AQ-3JX63AR-BDR6WMP-JQZ3KAK";
      folders.knowledge.path = "/snowscape/knowledge";
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

  # SillyTavern service
  systemd.services.sillytavern = let
    configFile = pkgs.writeText "sillytavern-config.yaml" ''
      dataRoot: ./data
      listen: false
      port: 8000
      protocol:
        ipv4: true
        ipv6: false
      whitelistMode: false
      enableForwardedWhitelist: false
      whitelist:
        - ::1
        - 127.0.0.1
      basicAuthMode: false
      enableCorsProxy: false
      enableUserAccounts: false
      securityOverride: false
      browserLaunch:
        enabled: false
    '';
  in {
    description = "SillyTavern LLM Frontend";
    after = ["network.target" "ollama.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.sillytavern}/bin/sillytavern --configPath ${configFile}";
      Restart = "on-failure";
      StateDirectory = "sillytavern";
      WorkingDirectory = "/var/lib/sillytavern";
    };
  };

  # Printing support
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      brlaser # Brother laser printer driver
      gutenprint
      gutenprintBin
    ];
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
    };
  };

  mountainous.tsnet-proxy = {
    enable = true;
    authKeyFile = config.age.secrets."tailscale-ephemeral".path;
    services.mcp = {
      hostname = "mcp";
      port = 8090;
    };
    services.tavern = {
      hostname = "tavern";
      port = 8000;
    };
    services.ollama = {
      hostname = "ollama";
      port = 11434;
    };
  };

  # Ollama for local LLM inference
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm; # AMD GPU
    environmentVariables = {
      OLLAMA_ORIGINS = "*"; # Allow all origins (secured by Tailscale)
    };
    loadModels = [
      "nomic-embed-text"
      "hermes3" # Best available for AI Dungeon-style storytelling
    ];
  };

  # Synapse MCP server for semantic search
  services.synapse = {
    enable = true;
    port = 3939;
    vaultPath = "/snowscape/knowledge";
    envPath = "/snowscape/knowledge/.synapse";
    user = "simonwjackson"; # Add this
    group = "users"; # Add this
  };

  # MCP Gateway - path-based routing for MCP servers
  mountainous.mcp-gateway = {
    enable = true;
    port = 8090;
    servers.synapse = {
      path = "synapse";
      upstream = "http://127.0.0.1:3939";
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
