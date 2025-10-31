{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./disko.nix
  ];

  # Configure agenix identity paths (SSH keys for decryption)
  # Point to persistent storage location since root is ephemeral (tmpfs)
  age.identityPaths = [
    "/tundra/permafrost/etc/ssh/ssh_host_rsa_key"
  ];

  # Configure agenix secrets
  age.secrets."zwave-js-secrets" = {
    file = ../../../../secrets/agenix/zwave-js-secrets.age;
    owner = "root";
    group = "root";
    mode = "400";
  };

  # UEFI boot configuration
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Hardware modules for rakku (Intel Celeron J1900)
  boot.initrd.availableKernelModules = [
    "ahci" # SATA controller
    "xhci_pci" # USB 3.0
    "usb_storage"
    "sd_mod"
  ];

  boot.kernelModules = [
    "igb" # Intel I211 Gigabit NIC
    "cp210x" # USB-to-serial for HubZ Smart Home Controller (Z-Wave/Zigbee)
  ];

  # Udev rules for HubZ Smart Home Controller
  # Creates persistent /dev/zwave and /dev/zigbee device names
  services.udev.extraRules = ''
    # HubZ Z-Wave interface (interface 0)
    SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="8a2a", ATTRS{bInterfaceNumber}=="00", SYMLINK+="zwave"

    # HubZ Zigbee interface (interface 1)
    SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="8a2a", ATTRS{bInterfaceNumber}=="01", SYMLINK+="zigbee"
  '';

  # Enable base profile
  mountainous.profiles.base.enable = true;

  # Home Assistant configuration
  services.home-assistant = {
    enable = true;
    openFirewall = true;

    # Add optimized compression libraries for better HTTP performance
    # package = pkgs.home-assistant.override {
    #   extraPackages = ps: [
    #     ps.zlib-ng # Faster zlib implementation
    #     ps.isal # Intel Storage Acceleration Library for compression
    #   ];
    # };

    extraComponents = [
      "default_config" # Essential integrations
      "zha" # Zigbee Home Automation
      "zwave_js" # Z-Wave JS integration
      "mqtt" # MQTT broker support
      "esphome" # ESPHome device integration
      "met" # Met.no weather service

      # Groups and helpers
      "group" # Group integration for creating groups
      "input_boolean" # Boolean input helpers
      "input_button" # Button helpers
      "input_datetime" # Date/time input helpers
      "input_number" # Number input helpers
      "input_select" # Select input helpers
      "input_text" # Text input helpers
      "counter" # Counter helpers
      "timer" # Timer helpers
      "schedule" # Schedule helpers

      # Voice and notifications
      "google_translate" # Text-to-speech
      "tts" # Text-to-speech platform

      # Media
      "music_assistant" # Music Assistant integration
      "sonos" # Sonos speakers
      "cast" # Chromecast/Google Cast
      "media_source" # Media source
      "radio_browser" # Internet radio stations

      # Mobile and cloud
      "mobile_app" # Mobile app support
      "cloud" # Nabu Casa cloud

      # Vacuum cleaners
      "roborock" # Roborock vacuum integration

      # Lights
      "yeelight" # Yeelight smart lights

      # Network and discovery
      "dhcp" # DHCP discovery
      "ssdp" # SSDP discovery
      "zeroconf" # Zeroconf/mDNS discovery
      "usb" # USB discovery

      # Utilities
      "sun" # Sun position
      "zone" # Zones
      "person" # Person tracking
      "device_tracker" # Device tracking
      "history" # History
      "logbook" # Logbook
      "recorder" # Recorder for database
    ];

    config = {
      # Basic configuration
      homeassistant = {
        name = "Home";
        unit_system = "metric";
        time_zone = "America/Denver";
        temperature_unit = "C";
      };

      # UI-managed configuration files
      # These files are created and managed by Home Assistant UI
      # and are persisted in /var/lib/hass
      automation = "!include automations.yaml";
      scene = "!include scenes.yaml";
      script = "!include scripts.yaml";
      group = "!include groups.yaml";
      input_boolean = "!include input_booleans.yaml";

      # Core integrations for sidebar panels
      history = {}; # History panel
      logbook = {}; # Activities panel
      map = {}; # Map panel
      media_source = {}; # Media browser
      recorder = {}; # Required for history

      # HTTP configuration
      http = {
        server_port = 8123;
        trusted_proxies = ["::1" "127.0.0.1"];
        use_x_forwarded_for = true;
      };
    };
  };

  # Z-Wave JS Server
  # Security keys are managed by agenix and backed up in git
  services.zwave-js = {
    enable = true;
    serialPort = "/dev/serial/by-id/usb-Silicon_Labs_HubZ_Smart_Home_Controller_61600558-if00-port0";
    port = 3000; # WebSocket port for Home Assistant to connect
    secretsConfigFile = config.age.secrets."zwave-js-secrets".path;
  };

  # Music Assistant - Music library manager and streaming server
  # Integrates with Home Assistant for centralized music control
  services.music-assistant = {
    enable = true;
    providers = [
      # Home Assistant integration
      "hass" # Required for HA integration
      "hass_players" # Use HA media players in Music Assistant

      # Streaming services
      "spotify"
      "ytmusic" # YouTube Music
      "tunein" # Internet radio

      # Local/Network sources
      "filesystem_local" # Local music files
      "filesystem_smb" # SMB/Network shares
      "jellyfin"
      "plex"

      # Player protocols
      # Note: airplay not available (requires unsupported OpenSSL 1.1)
      "chromecast" # Google Cast
      "dlna" # DLNA/UPnP
      "snapcast" # Multi-room audio
      "sonos" # Sonos speakers
    ];
  };

  # Override Music Assistant service to disable DynamicUser (incompatible with impermanence)
  systemd.services.music-assistant = {
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "music-assistant";
      Group = "music-assistant";
    };
  };

  # Create static user for Music Assistant
  users.users.music-assistant = {
    isSystemUser = true;
    group = "music-assistant";
    home = "/var/lib/music-assistant";
    createHome = false;
  };

  users.groups.music-assistant = {};

  # Grant Home Assistant and Z-Wave JS users access to serial devices
  users.users.hass.extraGroups = ["dialout"];

  # AirConnect - Bridge AirPlay to Sonos/UPnP speakers
  # Detects Sonos players and creates virtual AirPlay devices for each
  systemd.services.airconnect = {
    description = "AirConnect - AirPlay to Sonos/UPnP Bridge";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.airconnect}/bin/airupnp -l 1000:2000 -Z";
      Restart = "on-failure";
      RestartSec = "10s";
      DynamicUser = true;
    };
  };

  # Disable impermanence module (configure manually below)
  mountainous = {
    impermanence.enable = lib.mkForce false;
  };

  # Configure ephemeral root filesystem (tmpfs) for impermanence
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=2G" "mode=755"];
  };

  # Mark persistent storage as needed early in boot
  fileSystems."/tundra/permafrost".neededForBoot = true;

  # Local impermanence configuration for rakku (home-assistant box)
  environment.persistence."/tundra/permafrost" = {
    hideMounts = true;
    directories = [
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/tailscale"
      "/var/lib/hass" # Home Assistant configuration and data
      "/var/lib/zwave-js" # Z-Wave JS network data and secrets
      {
        directory = "/var/lib/music-assistant";
        user = "music-assistant";
        group = "music-assistant";
        mode = "0755";
      }
      {
        directory = "/home/simonwjackson";
        user = "simonwjackson";
        group = "users";
        mode = "0700";
      }
      {
        directory = "/tundra/igloo";
        user = "simonwjackson";
        group = "users";
        mode = "0700";
      }
      {
        directory = "/nix/var/nix/profiles/per-user/simonwjackson";
        user = "simonwjackson";
        group = "users";
        mode = "0755";
      }
    ];

    files = [
      "/etc/machine-id"
    ];
  };

  # Fix ownership of persistent directories on boot
  # Workaround for impermanence bug where parent directories are created with root ownership
  # See: https://github.com/nix-community/impermanence/issues/74
  systemd.tmpfiles.settings."10-persistent-ownership" = {
    "/tundra/permafrost/home/simonwjackson".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0700";
    };
    "/tundra/permafrost/tundra/igloo".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0700";
    };
    "/tundra/permafrost/nix/var/nix/profiles/per-user/simonwjackson".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0755";
    };
    "/tundra/permafrost/var/lib/hass".d = {
      user = "hass";
      group = "hass";
      mode = "0755";
    };
    "/tundra/permafrost/var/lib/music-assistant".d = {
      user = "music-assistant";
      group = "music-assistant";
      mode = "0755";
    };
  };

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };

    # SSH host keys in persistent storage
    # Keys will need to exist in /tundra/permafrost/etc/ssh/ before first boot
    hostKeys = [
      {
        path = "/tundra/permafrost/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };

  # User configuration
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "dialout" # Serial port access for HubZ controller
    ];
    openssh.authorizedKeys.keyFiles = [
      ../../../modules/nixos/user/id_rsa.pub
    ];
  };

  # Basic firewall configuration
  # Firewall disabled (using Tailscale for network security)
  # Services and their ports:
  #   - Home Assistant: 8123
  #   - Music Assistant: 8095
  #   - Z-Wave JS: 3000 (WebSocket)
  #   - SSH: 22
  networking.firewall = {
    enable = lib.mkForce false;
    allowedTCPPorts = [22 8123 8095 3000];
  };

  system.stateVersion = "24.11";
}
