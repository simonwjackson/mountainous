{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  korriApiPort = 3001;
  korriLibraryRoot = "/home/simonwjackson/.local/share/korri/library";
  korriStateRoot = "/home/simonwjackson/.local/state/korri";

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

  korriSwayStartup = pkgs.writeShellScript "korri-sway-startup" ''
    set -eu

    if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
      echo "korri-sway-startup: XDG_RUNTIME_DIR is required" >&2
      exit 1
    fi
    if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      echo "korri-sway-startup: WAYLAND_DISPLAY is required" >&2
      exit 1
    fi
    if [ -z "''${SWAYSOCK:-}" ]; then
      echo "korri-sway-startup: SWAYSOCK is required" >&2
      exit 1
    fi

    export XDG_CURRENT_DESKTOP=sway
    export XDG_SESSION_TYPE=wayland

    ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
      XDG_CURRENT_DESKTOP \
      XDG_SESSION_TYPE \
      XDG_RUNTIME_DIR \
      WAYLAND_DISPLAY \
      SWAYSOCK

    ${pkgs.systemd}/bin/systemctl --user start sunshine.service
  '';
in
{
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
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common = lib.mkForce {
      default = "*";
    };
  };

  # The default sway config (included below) defines a status bar. Sway's bar
  # blocks are additive and not overridable by id from outside, so we hide
  # every bar at runtime instead of forking the upstream config.
  home-manager.users.simonwjackson.xdg.configFile."sway/config".text = ''
    include ${pkgs.sway}/etc/sway/config
    exec_always ${pkgs.sway}/bin/swaymsg bar mode invisible
    exec_always ${korriSwayStartup}
  '';

  services = {
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd sway";
          user = "greeter";
        };
        initial_session = {
          command = "sway";
          user = "simonwjackson";
        };
      };
    };

    sunshine = {
      enable = true;
      openFirewall = true;
      autoStart = false;

      applications = {
        # Empty command: Sunshine's Desktop app streams the already-running
        # Sway session that starts this user service.
        apps = [
          {
            name = "Desktop (Sway)";
            image-path = "desktop.png";
          }
        ];

        env.PATH = lib.makeBinPath [
          pkgs.coreutils
          pkgs.nix
          pkgs.util-linux
        ];
      };

      settings = {
        output_name = 0;
        encoder = "vaapi";
        key_rightalt_to_key_win = "enabled";
      };
    };

    korri = {
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
        streamHost = {
          enable = true;
          appName = "Korri Stream";
        };
      };

      gameStream = {
        path = [
          pkgs.coreutils
          pkgs.nix
          pkgs.util-linux
        ];
        sunshine.outputLog = "${korriStateRoot}/game-stream-runner.log";
        sway.package = pkgs.sway;
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

  # services.korri.server.streamHost.enable pulls in services.korri.gameStream,
  # which owns the Sunshine /dev/uinput udev defaults needed for streamed input.

  users.users.simonwjackson.extraGroups = ["render" "video"];

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

  systemd.tmpfiles.settings."10-korri-game-stream" = {
    "${korriStateRoot}".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0700";
    };
  };

  environment.systemPackages = [
    pkgs.btrfs-progs
    pkgs.ethtool
  ];

  system.stateVersion = "24.11";
}
