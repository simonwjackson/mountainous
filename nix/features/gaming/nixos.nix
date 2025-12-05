{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkIf mkMerge;

  cfg = config.mountainous.gaming;
  device = config.mountainous.device;

  # Import streaming module configuration
  streamingModule = import ./streaming.nix {
    inherit config lib pkgs cfg;
  };
  streamingConfig = streamingModule.config;

  # Import library module configurations
  libraryRemoteModule = import ./lib/remote.nix {
    inherit config lib pkgs cfg;
  };
  libraryHybridModule = import ./lib/hybrid.nix {
    inherit config lib pkgs cfg;
  };

  # Role/capability-based decisions
  isServer = device.role == "server";
  isPortable = device.role == "portable";
  hasTouch = device.capabilities.touchscreen;
  isHandheld = device.capabilities.formFactor == "handheld" || device.capabilities.formFactor == "tablet";

  # Device-specific package sets
  basePackages = with pkgs; [
    # Steam tools (proton-ge-bin goes in extraCompatPackages, not here)
    gamescope
    steam-tui
    protontricks

    # Performance overlays
    mangohud

    # Moonlight streaming client
    moonlight-qt

    # Emulators
    citron # Nintendo Switch
  ];

  handheldPackages = with pkgs; [
    # Touch and gamepad tools for handheld devices
    # (can be extended as needed)
  ];

  desktopPackages = with pkgs; [
    # Additional desktop-only packages
    # (can be extended as needed)
  ];
in {
  options.mountainous.gaming = import ./options.nix {inherit lib;};

  config = mkIf cfg.enable (mkMerge [
    # Base gaming configuration (all device types)
    {
      # Enable Steam
      programs.steam = {
        enable = true;
        extraCompatPackages = with pkgs; [
          proton-ge-bin
        ];
        protontricks.enable = true;
      };

      # Enable hardware acceleration for video decoding (VA-API/VDPAU)
      # Required for game streaming and video playback
      hardware.graphics = {
        enable = true;
      };

      # Sound configuration with gaming optimizations
      services.pulseaudio.enable = false;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true; # Critical for 32-bit games
        pulse.enable = true;
        jack.enable = true;
        wireplumber.enable = true;

        # Low-latency gaming configuration
        wireplumber.configPackages = mkIf cfg.performance.lowLatencyAudio [
          (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/10-gaming.conf" ''
            monitor.alsa.rules = [
              {
                matches = [ { node.name = "~alsa_output.*" } ]
                actions = {
                  update-props = {
                    api.alsa.period-size = 256
                    api.alsa.headroom = 1024
                  }
                }
              }
            ]
          '')
        ];
      };

      # Enable rtkit for real-time audio priority
      security.rtkit.enable = true;

      # Gamepad support - uinput kernel module and udev rules
      boot.kernelModules = ["uinput"];

      services.udev.extraRules = ''
        SUBSYSTEM=="misc", KERNEL=="uinput", OPTIONS+="static_node=uinput", TAG+="uaccess"
      '';

      # Base packages
      environment.systemPackages = basePackages;
    }

    # Gamemode performance optimizer
    (mkIf cfg.performance.gamemode {
      programs.gamemode.enable = true;
      environment.systemPackages = with pkgs; [
        gamemode
      ];
    })

    # Desktop-specific configuration (not a server)
    (mkIf (!isServer) {
      environment.systemPackages = desktopPackages;
    })

    # Handheld/tablet-specific configuration (portable + small form factor)
    (mkIf isHandheld {
      environment.systemPackages = handheldPackages;
    })

    # Server configuration (minimal, streaming-focused)
    (mkIf isServer {
      # Server mode gets minimal packages
      # Streaming server will be configured in separate module
      environment.systemPackages = [];
    })

    # Touch-enabled devices get virtual keyboard support
    (mkIf hasTouch {
      # Could add touch-specific gaming tools here
    })

    # Streaming support (Sunshine)
    (mkIf cfg.streaming.enable streamingConfig)

    # Library remote (NFS mount)
    (mkIf cfg.library.remote.enable libraryRemoteModule.config)

    # Library hybrid (MergerFS local + remote)
    (mkIf cfg.library.hybrid.enable libraryHybridModule.config)
  ]);
}
