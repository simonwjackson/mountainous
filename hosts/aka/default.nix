{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  korriApiPort = 3001;

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

    steam = {
      enable = true;
      protontricks.enable = true;
      extraCompatPackages = [pkgs.proton-ge-bin];
    };

    gamemode.enable = true;

    sway = {
      enable = true;
      xwayland.enable = true;
      extraOptions = ["--unsupported-gpu"];
    };
  };

  # aka is a headless Korri source machine (no interactive desktop) and nothing
  # in the game-stream path needs xdg-desktop-portal: Sunshine captures the
  # screen directly (it streamed fine all along while the portal was failed).
  # Leaving the portal enabled cost ~25s of black screen per game launch: apps
  # (RetroArch) probe the portal on startup, and the frontend blocks ~25s on a
  # D-Bus activation timeout for each interface with no working backend. The
  # GTK backend can never start here (`cannot open display`), and even a
  # wlr-only config still stalled ~25s on the Settings interface. Measured
  # locally: portal enabled -> ~45s to first frame; disabled -> ~3s. Disable it.
  xdg.portal.enable = lib.mkForce false;

  services = {
    seatd.enable = true;

    pulseaudio.enable = false;

    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };

    # Sunshine config + supporting plumbing (sunshine.conf rendering,
    # firewall, /dev/uinput udev, avahi mDNS, uinput kernel module) is
    # owned by the upstream nixpkgs services.sunshine module. The actual
    # user unit that runs Sunshine is
    # `systemd.user.services.korri-sunshine`, emitted by
    # services.korri.daemon.streaming below: it runs sunshine-korri inside
    # Korri's user-level korri-session.target, ordered after the managed
    # korri-compositor user service. Korri forces
    # `services.sunshine.autoStart = false` to keep the upstream user unit
    # from racing with it.
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
      runtime = {
        user = "simonwjackson";
        group = "users";
        home = "/home/simonwjackson";
        stateRoot = "/var/lib/korri";
        createUser = false;
      };

      compositor.sway.package = config.programs.sway.package;

      rpcs3 = {
        enable = true;
        package = pkgs."rpcs3-v0.0.41-unstable-2026-06-04";
        gamesRoot = "/srv/lakes/towada/gaming/games/sony-playstation-3";
        stateRoot = "/home/simonwjackson/.config/rpcs3";
      };

      daemon = {
        host = "0.0.0.0";
        port = korriApiPort;
        serverId = "aka";
        publicApiBaseUrl = "http://192.168.1.117:${toString korriApiPort}";
        streamControl.enable = true;
        openFirewall = true;
        # Source-machine peers connect over the host's advertised LAN address.
        # Do not inherit Korri's older guessed interface defaults (`lan0`/tailscale0):
        # aka's wired interface is `eno1`, and a bad scope advertises an unreachable source.
        firewallInterfaces = [];
        # advertise.enable removed in Korri federation v1 (R14): every
        # korrid now advertises unconditionally with caps including
        # `source` baseline. Only the human-readable name is still tunable.
        advertise = {
          name = "Korri Stream on aka";
        };
        streaming.appName = "Korri Stream";
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

  security.rtkit.enable = true;

  boot.kernelModules = ["uinput"];

  services.udev.extraRules = ''
    SUBSYSTEM=="misc", KERNEL=="uinput", OPTIONS+="static_node=uinput", TAG+="uaccess"
  '';

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
    after = [
      "network-online.target"
      "tailscaled.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
    ];

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
      SupplementaryGroups = [
        "render"
        "video"
      ];
      ExecStart = akaLlamaQwen32Start;
      Restart = "on-failure";
      RestartSec = 5;
      TimeoutStartSec = "30min";
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ReadWritePaths = ["/home/simonwjackson/.cache"];
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
      LockPersonality = true;
      RestrictRealtime = true;
    };
  };

  environment.systemPackages = [
    pkgs.btrfs-progs
    pkgs.ethtool
    pkgs.gamescope
    pkgs.gamemode
    pkgs.mangohud
    pkgs.protontricks
  ];

  # Enable the RetroArch first-party plugin on this headless streaming source so
  # library entries can launch GBA content through @korri:retroarch/retroarch +
  # @korri:retroarch/mgba instead of the starter-kit `nix run nixpkgs#mgba` path.
  # The RetroArch closure itself (/etc/korri/bin/retroarch, /etc/korri/cores/*.so,
  # shaders, joypad autoconfig, sessiond PATH) is now provided by the
  # korri-source-machine module's retroarch source-machine plugin module; we only
  # opt the plugins into the runtime enable list here (korri-source-machine
  # enables @korri:gamescope by default).
  systemd.user.services.korrid.environment.KORRI_ENABLED_PLUGINS =
    lib.mkForce "@korri:gamescope,@korri:retroarch,@korri:rpcs3";

  system.stateVersion = "24.11";
}
