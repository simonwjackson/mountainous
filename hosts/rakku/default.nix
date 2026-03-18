{
  config,
  lib,
  pkgs,
  gomod2nix,
  ...
}: let
  buildGoApplication = gomod2nix.legacyPackages.${pkgs.stdenv.hostPlatform.system}.buildGoApplication;
  tsnet-proxy-pkg = buildGoApplication {
    pname = "tsnet-proxy";
    version = "1.0.0";
    src = ../../packages/tsnet-proxy;
    modules = ../../packages/tsnet-proxy/gomod2nix.toml;
    ldflags = ["-s" "-w"];
    doCheck = false;
  };
in {
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "rakku";

  # Rakku doesn't use presets.core (no standard HM user setup), so the
  # server-class defaults that used to come from modules/server are set
  # inline here instead of via presets.server.
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };
  nix.settings.auto-optimise-store = true;
  environment.systemPackages = with pkgs; [vim curl htop git jq];

  # ── Agenix ───────────────────────────────────────────────────────────

  age.identityPaths = lib.mkForce [
    "/tundra/permafrost/etc/ssh/ssh_host_rsa_key"
  ];

  age.secrets.tailscale-ephemeral = {
    owner = "tsnet-proxy";
    group = "tsnet-proxy";
  };

  # ── Tsnet Proxy ──────────────────────────────────────────────────────

  mountainous.features.tsnet-proxy = {
    enable = true;
    package = tsnet-proxy-pkg;
    authKeyFile = config.age.secrets.tailscale-ephemeral.path;
    services.habitat = {
      hostname = "habitat";
      protocol = "http";
      host = "localhost";
      port = 8123;
    };
  };

  # ── Home Assistant ───────────────────────────────────────────────────

  services.home-assistant = {
    enable = true;
    openFirewall = true;

    package = pkgs.home-assistant.override {
      extraPackages = ps: [
        ps.grpcio
        ps.google-nest-sdm
      ];
    };

    extraComponents = [
      "default_config"
      "zha"
      "zwave_js"
      "mqtt"
      "esphome"
      "met"
      "group"
      "input_boolean"
      "input_button"
      "input_datetime"
      "input_number"
      "input_select"
      "input_text"
      "counter"
      "timer"
      "schedule"
      "google_translate"
      "tts"
      "sonos"
      "cast"
      "media_source"
      "radio_browser"
      "nest"
      "ffmpeg"
      "mobile_app"
      "cloud"
      "application_credentials"
      "roborock"
      "yeelight"
      "dhcp"
      "ssdp"
      "zeroconf"
      "usb"
      "sun"
      "zone"
      "person"
      "device_tracker"
      "history"
      "logbook"
      "recorder"
    ];

    config = {
      homeassistant = {
        name = "Home";
        unit_system = "metric";
        time_zone = "America/Denver";
        temperature_unit = "C";
        external_url = "https://habitat.hummingbird-lake.ts.net";
        internal_url = "http://localhost:8123";
      };

      automation = "!include automations.yaml";
      binary_sensor = "!include binary_sensors.yaml";
      group = "!include groups.yaml";
      input_boolean = "!include input_booleans.yaml";
      input_datetime = "!include input_datetime.yaml";
      input_number = "!include input_number.yaml";
      scene = "!include scenes.yaml";
      script = "!include scripts.yaml";
      sensor = "!include sensors.yaml";

      history = {};
      logbook = {};
      map = {};
      media_source = {};
      recorder = {};

      tts = [
        {
          platform = "google_translate";
          service_name = "google_translate_say";
        }
      ];

      http = {
        server_port = 8123;
        trusted_proxies = ["::1" "127.0.0.1"];
        use_x_forwarded_for = true;
      };
    };
  };

  # ── Z-Wave JS ────────────────────────────────────────────────────────

  services.zwave-js = {
    enable = true;
    serialPort = "/dev/serial/by-id/usb-Silicon_Labs_HubZ_Smart_Home_Controller_61600558-if00-port0";
    port = 3000;
    secretsConfigFile = config.age.secrets.zwave-js-secrets.path;
  };

  users.users.hass.extraGroups = ["dialout"];

  # ── Tinyproxy (residential IP proxy for YouTube/scrapers) ────────────

  services.tinyproxy = {
    enable = true;
    settings = {
      Port = 8888;
      Listen = "0.0.0.0";
      Timeout = 600;
      Allow = ["127.0.0.1" "100.64.0.0/10"]; # localhost + Tailscale CGNAT
      MaxClients = 20;
      LogLevel = "Warning";
      ConnectPort = [443 563]; # HTTPS CONNECT support
    };
  };

  # ── AirConnect ───────────────────────────────────────────────────────

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

  # ── Ephemeral root (tmpfs) + Impermanence ───────────────────────────

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=2G" "mode=755"];
  };

  fileSystems."/nix".neededForBoot = true;
  fileSystems."/tundra/permafrost".neededForBoot = true;

  environment.persistence."/tundra/permafrost" = {
    hideMounts = true;
    directories = [
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/tailscale"
      "/var/lib/hass"
      "/var/lib/zwave-js"
      {
        directory = "/var/lib/tsnet-proxy-habitat";
        user = "tsnet-proxy";
        group = "tsnet-proxy";
        mode = "0700";
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
    "/tundra/permafrost/var/lib/tsnet-proxy-habitat".d = {
      user = "tsnet-proxy";
      group = "tsnet-proxy";
      mode = "0700";
    };
  };

  # ── SSH ──────────────────────────────────────────────────────────────

  services.openssh.hostKeys = [
    {
      path = "/tundra/permafrost/etc/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

  # ── Users ────────────────────────────────────────────────────────────

  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video" "dialout"];
  };

  # ── Network ──────────────────────────────────────────────────────────

  # Tailscale system daemon (machine-level connectivity) is enabled globally
  # from flake defaults via mountainous.features.tailscale.

  networking.wireless.enable = lib.mkForce false;
  networking.firewall.enable = lib.mkForce false;

  system.stateVersion = "24.11";
}
