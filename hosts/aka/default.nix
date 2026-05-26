{
  inputs,
  lib,
  pkgs,
  ...
}: let
  korriApiPort = 3001;
  korriLibraryRoot = "/home/simonwjackson/.local/share/korri/library";

  akaLlamaQwen32Port = 18080;
  akaLlamaQwen32CtxSize = 32768;
  akaLlamaQwen32Host = "0.0.0.0";
  akaLlamaQwen32DefaultModel = "bartowski/Qwen2.5-Coder-32B-Instruct-GGUF:Q4_K_S";
  akaLlamaQwen32FallbackModel = "Qwen/Qwen2.5-Coder-32B-Instruct-GGUF:q3_k_m";
  akaLlamaQwen32Package = pkgs.llama-cpp.override {
    vulkanSupport = true;
  };

  akaLlamaQwen32Start = pkgs.writeShellScript "aka-llama-qwen32-start" ''
    set -euo pipefail

    : "''${AKA_LLAMA_QWEN32_MODEL:=${akaLlamaQwen32DefaultModel}}"
    : "''${AKA_LLAMA_QWEN32_CTX_SIZE:=${toString akaLlamaQwen32CtxSize}}"
    : "''${AKA_LLAMA_QWEN32_HOST:=${akaLlamaQwen32Host}}"
    : "''${AKA_LLAMA_QWEN32_PORT:=${toString akaLlamaQwen32Port}}"

    export HOME=/home/simonwjackson
    export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"
    export HF_HOME="''${HF_HOME:-$HOME/.cache/huggingface}"

    exec ${akaLlamaQwen32Package}/bin/llama-server \
      -hf "$AKA_LLAMA_QWEN32_MODEL" \
      --device Vulkan0 \
      --gpu-layers all \
      --ctx-size "$AKA_LLAMA_QWEN32_CTX_SIZE" \
      --host "$AKA_LLAMA_QWEN32_HOST" \
      --port "$AKA_LLAMA_QWEN32_PORT"
  '';
in {
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "aka";
  time.timeZone = "America/Denver";

  mountainous = {
    presets = {
      core.enable = true;
      desktop.enable = false;
    };

    features = {
      device = {
        role = "desktop";
        capabilities = {
          battery = false;
          formFactor = "tower";
          touchscreen = false;
        };
      };

      bluetooth.enable = true;
      gaming.enable = false;
      hyprland.enable = false;
      hibernation = {
        enable = true;
        resumeDevice = "/dev/disk/by-id/nvme-SAMSUNG_MZQLB7T6HMLA-00007_S4BGNC0R803650-part2";
        swap.mode = "partition";
      };
    };
  };

  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  networking = {
    networkmanager.enable = true;

    # Intel I225-V wired NIC. Keep wake-on-LAN independent of NetworkManager
    # profile state so the machine can be woken from suspend/hibernate/off.
    interfaces.eno1.wakeOnLan.enable = true;
  };

  powerManagement.enable = true;

  systemd.sleep.settings.Sleep = {
    AllowSuspend = true;
    AllowHibernation = true;
    AllowSuspendThenHibernate = true;
    HibernateDelaySec = "2h";
  };

  programs = {
    hyprland.enable = false;
    sway = {
      enable = true;
      xwayland.enable = true;
    };
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    config.common = lib.mkForce {
      default = "*";
    };
  };

  services = {
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd sway";
          user = "greeter";
        };
      };
    };

    seatd.enable = true;

    # Sunshine config + supporting plumbing (sunshine.conf rendering,
    # firewall, /dev/uinput udev, avahi mDNS, uinput kernel module) is
    # owned by the upstream nixpkgs services.sunshine module. The actual
    # systemd unit that runs Sunshine is
    # `systemd.services.korri-sunshine`, emitted by
    # services.korri.server.streaming below: it runs sunshine-korri as a
    # system service ordered after korri-compositor.service, so streaming
    # works at boot without a graphical-session.target dance. Korri
    # forces `services.sunshine.autoStart = false` to keep the upstream
    # user unit from racing with it.
    sunshine = {
      enable = true;
      openFirewall = true;

      settings = {
        output_name = 0;
        encoder = "vaapi";
        key_rightalt_to_key_win = "enabled";
      };
    };

    korri = {
      client.enable = false;

      compositor = {
        enable = true;
        kiosk.enable = false;
        user = "simonwjackson";
        group = "users";
        createUser = false;
        home = "/home/simonwjackson";
        wants = ["seatd.service"];
        after = ["seatd.service"];
        sway.package = pkgs.sway;
      };

      input.provider = {
        enable = true;
        name = "inputplumber";
      };

      server = {
        enable = true;
        serviceMode = "system";
        user = "simonwjackson";
        group = "users";
        host = "0.0.0.0";
        port = korriApiPort;
        serverId = "aka";
        library.root = korriLibraryRoot;
        publicApiBaseUrl = "http://192.168.1.117:${toString korriApiPort}";
        streamControl.enable = true;
        openFirewall = true;
        advertise = {
          enable = true;
          name = "Korri Stream on aka";
        };
        streaming = {
          enable = true;
          appName = "Korri Stream";
        };
      };
    };

    logind.settings.Login = {
      HandlePowerKey = "suspend-then-hibernate";
      HandleSuspendKey = "suspend";
      HandleHibernateKey = "hibernate";
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  users.users.simonwjackson.extraGroups = [
    "input"
    "render"
    "seat"
    "video"
  ];

  # Keep the llama.cpp server reachable from trusted Tailscale peers without
  # opening port 18080 on the broad LAN. The core preset marks tailscale0 as a
  # trusted interface; intentionally do not add this port to allowedTCPPorts.
  systemd.services.aka-llama-qwen32 = {
    description = "Qwen2.5-Coder 32B llama.cpp server for Pi";
    after = ["network-online.target" "tailscaled.service"];
    wants = ["network-online.target" "tailscaled.service"];

    environment = {
      HOME = "/home/simonwjackson";
      XDG_CACHE_HOME = "/home/simonwjackson/.cache";
      HF_HOME = "/home/simonwjackson/.cache/huggingface";
      AKA_LLAMA_QWEN32_FALLBACK_MODEL = akaLlamaQwen32FallbackModel;
    };

    serviceConfig = {
      Type = "simple";
      User = "simonwjackson";
      Group = "users";
      SupplementaryGroups = ["render" "video"];
      ExecStart = akaLlamaQwen32Start;
      Restart = "on-failure";
      RestartSec = 5;
      TimeoutStartSec = "30min";
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = ["/home/simonwjackson/.cache"];
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
      LockPersonality = true;
      RestrictRealtime = true;
    };
  };

  environment.systemPackages = [
    pkgs.btrfs-progs
    pkgs.ethtool
  ];

  system.stateVersion = "24.11";
}
