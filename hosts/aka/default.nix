{
  inputs,
  lib,
  pkgs,
  ...
}: let
  korriApiPort = 3001;
  korriLibraryRoot = "/home/simonwjackson/.local/share/korri/library";
  korriStateRoot = "/home/simonwjackson/.local/state/korri";
  korriPackages = inputs.korri.packages.${pkgs.system};
  korriHeadlessTools = pkgs.stdenv.mkDerivation {
    pname = "korri-headless-tools";
    version = "1.0.0";

    src = inputs.korri;

    nativeBuildInputs = [
      pkgs.bun
      pkgs.nodejs_20
      pkgs.makeWrapper
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"

      rm -rf node_modules
      mkdir -p node_modules
      cp -R ${korriPackages.bun-deps}/. node_modules/
      chmod -R u+w node_modules

      cat > korri-lan-stream-advertise.ts <<'EOF'
      import { advertiseStreamHost } from "./tools/device/lan-stream-advertise"

      const portValue = process.env.KORRI_STREAM_ADVERTISE_PORT ?? process.env.PORT ?? "3001"
      const port = Number.parseInt(portValue, 10)
      const capabilities = (process.env.KORRI_STREAM_ADVERTISE_CAPABILITIES ?? "stream,source")
        .split(",")
        .map(capability => capability.trim())
        .filter(Boolean)

      const advertisement = advertiseStreamHost({
        name: process.env.KORRI_STREAM_ADVERTISE_NAME ?? "Korri Stream on aka",
        hostId: process.env.KORRI_STREAM_ADVERTISE_HOST_ID ?? "aka",
        port,
        capabilities,
      })

      console.log("Advertising Korri stream source on port " + port)

      const stop = async () => {
        await advertisement.stop()
        process.exit(0)
      }

      process.on("SIGINT", () => void stop())
      process.on("SIGTERM", () => void stop())
      await new Promise(() => undefined)
      EOF

      bun build tools/http/server.ts --target=bun --external '@proseql/*' --outfile=korri-api.js
      bun build korri-lan-stream-advertise.ts --target=bun --outfile=korri-lan-stream-advertise.js

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/korri-headless-tools" "$out/bin"
      cp korri-api.js korri-lan-stream-advertise.js "$out/share/korri-headless-tools/"
      cp -R node_modules "$out/share/korri-headless-tools/node_modules"

      makeWrapper ${pkgs.bun}/bin/bun "$out/bin/korri-api" \
        --add-flags "$out/share/korri-headless-tools/korri-api.js"
      makeWrapper ${pkgs.bun}/bin/bun "$out/bin/korri-lan-stream-advertise" \
        --add-flags "$out/share/korri-headless-tools/korri-lan-stream-advertise.js"

      runHook postInstall
    '';
  };

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

    ${pkgs.coreutils}/bin/install -d -m 700 "$XDG_RUNTIME_DIR/korri-game-stream"
    ${pkgs.systemd}/bin/systemctl --user start sunshine.service korri-api.service korri-lan-stream-advertise.service
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
    firewall = {
      allowedTCPPorts = [korriApiPort];
      allowedUDPPorts = [5353];
    };

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

  # The default sway config (included below) defines a status bar. Sway's bar
  # blocks are additive and not overridable by id from outside, so we hide
  # every bar at runtime instead of forking the upstream config.
  home-manager.users.simonwjackson.xdg.configFile."sway/config".text = ''
    include ${pkgs.sway}/etc/sway/config
    exec_always ${pkgs.sway}/bin/swaymsg bar mode invisible
    exec_always ${korriSwayStartup}
  '';

  home-manager.users.simonwjackson.systemd.user.services = {
    korri-api = {
      Unit = {
        Description = "Korri headless source RPC API";
      };
      Service = {
        ExecStart = "${korriHeadlessTools}/bin/korri-api";
        Restart = "on-failure";
        RestartSec = 2;
        Environment = [
          "HOST=0.0.0.0"
          "PORT=${toString korriApiPort}"
          "KORRI_STREAM_CONTROL_ENABLED=1"
          "KORRI_HEADLESS_SOURCE_ONLY=1"
          "KORRI_LIBRARY_SOURCE=proseql"
          "KORRI_LIBRARY_ROOT=${korriLibraryRoot}"
        ];
      };
      Install.WantedBy = ["default.target"];
    };

    korri-lan-stream-advertise = {
      Unit = {
        Description = "Advertise aka as a Korri stream source";
        After = ["korri-api.service"];
        Wants = ["korri-api.service"];
      };
      Service = {
        ExecStart = "${korriHeadlessTools}/bin/korri-lan-stream-advertise";
        Restart = "on-failure";
        RestartSec = 2;
        Environment = [
          "KORRI_STREAM_ADVERTISE_NAME=Korri Stream on aka"
          "KORRI_STREAM_ADVERTISE_HOST_ID=aka"
          "KORRI_STREAM_ADVERTISE_PORT=${toString korriApiPort}"
          "KORRI_STREAM_ADVERTISE_CAPABILITIES=stream,source"
        ];
      };
      Install.WantedBy = ["default.target"];
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

      applications.env.PATH = lib.makeBinPath [
        pkgs.coreutils
        pkgs.nix
        pkgs.util-linux
      ];

      settings = {
        output_name = 0;
        encoder = "vaapi";
        key_rightalt_to_key_win = "enabled";
      };
    };

    korri.gameStream = {
      enable = true;
      appName = "Korri Stream";
      intentMaxAgeSeconds = 300;
      path = [
        pkgs.coreutils
        pkgs.nix
        pkgs.util-linux
      ];
      gamescope.enable = false;
      sunshine.outputLog = "${korriStateRoot}/game-stream-runner.log";
      sway = {
        repair = false;
        package = pkgs.sway;
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

  systemd.tmpfiles.settings."10-korri-game-stream" = {
    "${korriLibraryRoot}".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0700";
    };
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
