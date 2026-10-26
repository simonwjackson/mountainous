{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./avahi.nix
    ./commitments.nix
    ./disko.nix
    ./hardware.nix
    ./nscd.nix
  ];

  networking = {
    hostName = "zao";
    networkmanager.enable = true;
  };
  time.timeZone = "America/Denver";

  nixpkgs.config.allowUnfree = true;

  programs.nix-ld.enable = true;
  virtualisation.podman.enable = true;
  environment.sessionVariables.ASPIRE_CONTAINER_RUNTIME = "podman";

  # ── Memory pressure ──────────────────────────────────────────────
  # Zao ships with 31 GiB RAM and 0 swap. On 2026-06-01 a single `nix`
  # eval process reached ~15.2 GiB anon RSS during a full Nix test evaluation,
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
    presets.server.enable = true;

    # Towada, its media library and Jellyfin moved to Unzen (cairn) with the
    # enclosure. Zao keeps no storage array.

    # ── Networking ───────────────────────────────────────────────────
    features.tsnet-proxy = {
      enable = true;
      package = pkgs.tsnet-proxy;
      authKeyFile = config.age.secrets.tailscale-authkey.path;
    };

    # ── Services ─────────────────────────────────────────────────────
    features.dictation-backend = {
      enable = true;
      audioContext = 1500;
      proxy.enable = true;
    };

    # Korri's aarch64 outputs must be built on aarch64 hardware: Fuji and Yari.
    # Naming them once means a plain `nix build` reaches them without
    # --builders, and Nix spreads one build's derivations across both.
    features.nix-builders = {
      enable = true;
      use = ["fuji" "yari"];
    };

    # Zao builds Korri's x86_64 outputs. Reading them from Korri's cache is
    # cheaper than rebuilding what another peer already built and signed. It
    # publishes through Korri's own `nix run .#korri-nix-cache-publish`; nothing
    # here watches Zao's builds, which would also publish Zao's own system.
    features.korri-cache.enable = true;

    features.device = {
      role = "portable";
      capabilities = {
        battery = true;
        formFactor = "laptop";
        touchscreen = false;
      };
    };
  };

  # Keep Intel VAAPI available independently of Sunshine's NVENC encoder.
  hardware.graphics.extraPackages = [pkgs.intel-media-driver];

  services.korriLinuxHost = {
    enable = true;
    runtimeUser = "simonwjackson";
    runtimeUid = 1000;
    runtimeGroup = "users";
    runtimeGid = 100;
    firewallInterfaces = ["tailscale0"];
    relays = [
      "wss://relay.nostr.band"
      "wss://relay.primal.net"
    ];
    ownerBindingFile = ./korrid-owner-binding.json;
    compositor.renderDevice = "/dev/dri/by-path/pci-0000:01:00.0-render";
    compositor.mode = "1920x1080@120Hz";
    compositor.renderer = "pixman";
    # Korri's default local-signer GID (978) is already Podman's GID on Zao
    # (/var/lib/nixos/gid-map). 974 is unused there.
    serviceIdentities.localSignerGid = 974;
  };

  # korrid now derives its advertised peer origins from live interfaces; only
  # the Moonlight address remains a declared announcement.
  services.korridLinuxDevice.moonlightAddress = "zao:47989";

  # Korri's product module sets this; korriLinuxHost does not. Without it
  # korrid validates every systemd helper call with an empty stream root,
  # host-session recovery never resolves ("host session authority is
  # unresolved", HostRecoveryBlocked) and no game can start. The value is the
  # product default: Sunshine's state, hidden from every game unit. korrid
  # also lists it in its own InaccessiblePaths without a "-" prefix, so the
  # directory must exist or korrid will not start.
  services.korridLinuxDevice.streamPrivateStateRoot = "/home/simonwjackson/.config/sunshine";

  # korrid reads the plugin host's registry. No plugins are installed here; the
  # official publisher binding comes from Korri's own product requirements so
  # this repository keeps no second copy of the key.
  services.korri.pluginHost = {
    enable = true;
    publishers."@korri" =
      (import "${inputs.korri-input-host}/nix/product/requirements.nix" {korri = inputs.korri-input-host;})
      .constants
      .publishers
      ."@korri";
  };

  # TEMPORARY (Zao only; see docs/nix-commands.md "Zao temporary workarounds"):
  # Korri's services/inputd/nix/sway-activity.nix asserts sway-unwrapped 1.12
  # and wlroots 0.20.2 from the host's pkgs, and the fleet Nixpkgs still has
  # sway 1.11 and no wlroots_0_20. Take both from the Nixpkgs that Korri's own
  # lock pins.
  # Exit condition: delete this overlay when the fleet Nixpkgs provides
  # sway-unwrapped 1.12 and wlroots_0_20 0.20.2 and Zao still evaluates
  # without it.
  nixpkgs.overlays = [
    (_: _: {
      inherit (inputs.korri-input-host.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}) sway-unwrapped wlroots_0_20;
    })
  ];

  # TEMPORARY (see docs/nix-commands.md "Zao temporary workarounds"):
  # the plugin host imports Korri's nix/device-cache/nixos-module.nix,
  # which force-disables local and remote builds ("Device policy only. CI and
  # development machines must not import this module."; its README: "CI and
  # development builders do not import this device policy."). Zao is a build
  # host, so restore what it had before. Priority 49 beats that module's
  # mkForce (50). `fallback` is not restored: the module forces false, which is
  # also Nix's default and what Zao ran with before.
  # Exit condition: remove these three mkOverride 49 lines after
  # korri-os/korri#249 is fixed and Zao's korri-input-host is bumped past that
  # fix. Zao must stay a build machine: check that nix.settings.max-jobs and
  # nix.distributedBuilds keep these values without the override.
  nix.distributedBuilds = lib.mkOverride 49 true;
  nix.settings = {
    max-jobs = lib.mkOverride 49 "auto";
    # Nix's own default; NixOS leaves it unset while distributedBuilds is on.
    builders = lib.mkOverride 49 "@/etc/nix/machines";
  };

  users.users.simonwjackson.extraGroups = [
    "lp"
    "media"
    "networkmanager"
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
    nssmdns6 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # Storage probes (Myoko's bar, alerts) read this: Zao expects no array.
  environment.etc."towada-moved".text = "unzen\n";

  # ── Secrets ────────────────────────────────────────────────────────
  age.secrets.tailscale-authkey = {
    owner = "tsnet-proxy";
    group = "tsnet-proxy";
  };

  system.stateVersion = "26.05";
}
