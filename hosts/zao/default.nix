{
  config,
  lib,
  pkgs,
  ...
}: let
  korriApiPort = 39217;
in {
  imports = [
    ./disko.nix
    ./hardware.nix
  ];

  networking.hostName = "zao";
  time.timeZone = "America/Denver";

  nixpkgs.config.allowUnfree = true;

  # ── Memory pressure ──────────────────────────────────────────────
  # Zao ships with 31 GiB RAM and 0 swap. On 2026-06-01 a single `nix`
  # eval process reached ~15.2 GiB anon RSS during `just test-nix`,
  # triggered the kernel OOM killer inside the user tmux scope, and
  # made interactive SSH sessions unresponsive while sshd itself stayed
  # up (oom_score_adj=-1000). zram-backed swap absorbs the burst at the
  # cost of CPU instead of the OOM killer; zstd gives a good
  # ratio/throughput tradeoff for Nix eval heaps. memoryPercent=50 caps
  # the compressed device at half of RAM so it cannot starve real
  # workloads.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  mountainous = {
    presets.core = {
      enable = true;
      # TODO: remove before committing
      passwordHash = "$6$bGAB/OPwyzz7AKMK$5MV3Ak8izkYQDdRFmzt8R/8joddHc1fHXMK9qBbwM3UQRlRMwX5JtsyGpq5tnU7BX7K8ibq1HshEp2kvKv/aA1";
    };
    presets.workstation.enable = true;
    presets.server.enable = true;

    features.disk-array = {
      enable = true;
      # NOTE: The original config had 6 disks (iceberg00–05). Only 5 are
      # physically present as of 2026-04-05. The missing 6th disk was:
      #   id = "05"; device = "/dev/disk/by-id/usb-TerraMas_TDAS_7SGK9H0C-0:0"
      # It appeared in the old fstab but is not connected. Investigate whether
      # this disk still exists and should be added back to the lake.
      pools.towada = {
        disks = [
          {
            id = "00";
            device = "/dev/disk/by-id/usb-TerraMas_TDAS_7SGKDA3C-0:0";
            mountOptions = ["defaults" "nofail" "noatime" "lazytime" "logbufs=8" "allocsize=1m" "x-systemd.device-timeout=90"];
          }
          {
            id = "01";
            device = "/dev/disk/by-id/usb-TerraMas_TDAS_VRJVWS3K-0:0";
            mountOptions = ["defaults" "nofail" "noatime" "lazytime" "logbufs=8" "allocsize=1m" "x-systemd.device-timeout=90"];
          }
          {
            id = "02";
            device = "/dev/disk/by-id/usb-TerraMas_TDAS_VGH3KRAG-0:0";
            mountOptions = ["defaults" "nofail" "noatime" "nodiratime" "lazytime" "logbufs=8" "allocsize=64m" "x-systemd.device-timeout=90"];
          }
          {
            id = "03";
            device = "/dev/disk/by-id/usb-TerraMas_TDAS_VGH13XMG-0:0";
            mountOptions = ["defaults" "nofail" "noatime" "nodiratime" "lazytime" "logbufs=8" "allocsize=64m" "x-systemd.device-timeout=90"];
          }
          {
            id = "04";
            device = "/dev/disk/by-id/usb-TerraMas_TDAS_WD-CA081PBK-0:0";
            mountOptions = ["defaults" "nofail" "noatime" "lazytime" "logbufs=8" "allocsize=1m" "x-systemd.device-timeout=90"];
          }
        ];

        cache.enable = true;

        mergerfs.dataDisks = ["00" "01" "04"];

        snapraid = {
          enable = true;
          dataDisks = ["00" "01" "04"];
          parityDisks = ["02" "03"];
        };

        usb = {
          disableAutosuspend = true;
          udevRules = [
            {
              vendor = "152d";
              product = "0578";
            }
          ];
        };
      };
    };

    features.media = {
      enable = true;
      root = "/srv/lakes/towada";
    };

    features.media-tiering = {
      enable = true;
      role = "sink";
      peerHost = "yari";
      # localBackingRoot defaults to /srv/lakes/towada/media (inside the
      # lake mergerfs). Media has been moved from the legacy movies/ and
      # series/ dirs into media/{movies,tv} on each shore, so no bind
      # mounts (localSources) are needed.
    };

    # ── Networking ───────────────────────────────────────────────────
    features.tsnet-proxy = {
      enable = true;
      package = pkgs.tsnet-proxy;
      authKeyFile = config.age.secrets.tailscale-authkey.path;
    };

    # ── Services ─────────────────────────────────────────────────────
    features.pyxis = {
      enable = true;
      # Sonos must be able to fetch streams directly over the LAN; do not
      # advertise the Tailscale hostname here.
      openFirewall = true;
      externalUrl = "http://192.168.1.243:8765";
      allowedHosts = ["pyxis.hummingbird-lake.ts.net"];
      sources.pandora = {
        username = "simon@simonwjackson.com";
        passwordFile = config.age.secrets.pyxis-pandora-password.path;
      };
      proxy = {
        enable = true;
        hostname = "pyxis";
        openFirewall = false;
      };
      backup = {
        enable = true;
        passphraseFile = config.age.secrets.borg-passphrase.path;
      };
    };

    features.jellyfin = {
      enable = true;
      # Opened to the LAN so the LG webOS TV (no Tailscale client) can reach Jellyfin directly.
      openFirewall = true;
      bootstrap = {
        enable = true;
        admin = {
          username = "simonwjackson";
          passwordFile = config.age.secrets.jellyfin-pass.path;
        };
        serverName = "zao";
        remoteAccess = true;
        libraries = {
          tv = {
            name = "TV";
            path = "/srv/range/media/tv";
          };
          movies = {
            name = "Movies";
            path = "/srv/range/media/movies";
          };
        };
      };
      proxy = {
        enable = true;
        hostname = "watch";
        openFirewall = false;
      };
    };

    features.device = {
      role = "portable";
      capabilities = {
        battery = true;
        formFactor = "laptop";
        touchscreen = false;
      };
    };
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

    sunshine = {
      enable = true;
      openFirewall = true;

      settings = {
        output_name = 0;
        encoder = "nvenc";
        key_rightalt_to_key_win = "enabled";
      };
    };

    korri = {
      client.enable = false;

      runtime = {
        user = "simonwjackson";
        group = "users";
        home = "/home/simonwjackson";
        createUser = false;
      };

      # Intentionally not enabling services.korri.login: zao uses tuigreet via
      # services.greetd below for interactive sway sessions and runs korrid as a
      # background daemon, instead of greetd auto-starting the Korri user target.

      compositor = {
        enable = true;
        kiosk.enable = false;
        user = "simonwjackson";
        group = "users";
        createUser = false;
        home = "/home/simonwjackson";
        wants = ["seatd.service"];
        after = ["seatd.service"];
        sway.package = config.programs.sway.package;
      };

      input.provider = {
        enable = true;
        name = "inputplumber";
      };

      gameStream.displayCompat.extraEnv = {
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        __NV_PRIME_RENDER_OFFLOAD = "1";
        __VK_LAYER_NV_optimus = "NVIDIA_only";
      };

      daemon = {
        enable = true;
        host = "0.0.0.0";
        port = korriApiPort;
        serverId = "zao";
        publicApiBaseUrl = "http://192.168.1.243:${toString korriApiPort}";
        streamControl.enable = true;
        openFirewall = true;
        firewallInterfaces = ["tailscale0"];
        # advertise.enable removed in Korri federation v1 (R14): every
        # korrid now advertises unconditionally with caps including
        # `source` baseline. Only the human-readable name is still tunable.
        advertise = {
          name = "Korri Stream on zao";
        };
        streaming = {
          enable = true;
          appName = "Korri Stream";
        };
      };
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
    "lp"
    "media"
    "networkmanager"
    "render"
    "seat"
    "video"
  ];

  environment.systemPackages = [
    pkgs.gamescope
    pkgs.gamemode
    pkgs.mangohud
    pkgs.protontricks
  ];

  # ── Printing ─────────────────────────────────────────────────────
  # Brother HL-L2300D mono laser connected via USB (idVendor=04f9,
  # idProduct=0061, serial=U63878A0N138131). brlaser is the recommended
  # open-source driver. The deviceUri below is tied to this specific
  # physical unit's USB serial.
  services.printing = {
    enable = true;
    drivers = [pkgs.brlaser];
    # Share the printer with other hosts on the LAN.
    listenAddresses = ["*:631"];
    allowFrom = ["all"];
    browsing = true;
    defaultShared = true;
    openFirewall = true;
  };

  # Declaratively ensure the Office Printer queue exists and is the
  # default. This nixpkgs revision doesn't have services.printing.
  # ensurePrinters, so we wire up lpadmin ourselves via a oneshot unit
  # that runs after cupsd is ready. lpadmin is idempotent: it modifies
  # an existing queue with the same name rather than erroring.
  systemd.services.ensure-office-printer = {
    description = "Ensure Office Printer CUPS queue";
    after = ["cups.service"];
    requires = ["cups.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [pkgs.cups];
    script = ''
      # Wait for cupsd to accept connections.
      for i in $(seq 1 30); do
        if lpstat -r >/dev/null 2>&1; then break; fi
        sleep 1
      done

      lpadmin -p Office_Printer -E \
        -v 'usb://Brother/HL-L2300D%20series?serial=U63878A0N138131' \
        -m 'drv:///brlaser.drv/brl2300d.ppd' \
        -D 'Office Printer' \
        -L 'Office' \
        -o printer-is-shared=true
      lpadmin -d Office_Printer
    '';
  };

  # Advertise the shared printer via mDNS so other machines auto-discover it.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  networking.firewall.allowedTCPPorts = [
    8765 # Pyxis service port
    9000 # Pyxis dev server port
  ];

  # ── Secrets ────────────────────────────────────────────────────────
  age.secrets.tailscale-authkey = {
    owner = "tsnet-proxy";
    group = "tsnet-proxy";
  };

  age.secrets.pyxis-pandora-password = {
    file = config.age.secrets.credentials-pandora-password.file;
    owner = "root";
    group = "pyxis-secrets";
    mode = "0440";
  };

  system.stateVersion = "26.05";
}
