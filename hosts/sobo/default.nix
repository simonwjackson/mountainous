# AYN Odin 2 Portal — NixOS guest inside a systemd-nspawn container on
# patched ROCKNIX (see github:simonwjackson/nix-on-rocks). Most of the
# system is composed by the upstream `main-space` + `odin2portal` modules
# wired in via `extraModules` in mountainous/flake.nix:
#
#   - hostname forced to "sobo" by upstream odin2portal profile
#   - boot.isContainer = true, no disko, no boot loader
#   - sway kiosk session, guest-owned audio/input/network/tailscale
#   - sshd on :2222 (upstream policy)
#
# This file owns mountainous-side adjustments only: turning off mountainous
# features that the guest already owns, and dialling in presets/syncthing
# wiring the way mountainous does it for every other host.
{
  lib,
  inputs,
  pkgs,
  config,
  ...
}: {
  mountainous = {
    presets.core = {
      enable = true;
      # No agenix password file yet for sobo; default to disabled login until
      # one is rotated in. The user can still SSH in with key auth via the
      # upstream sshd on :2222.
      passwordHash = "!";
    };

    features = {
      # Upstream main-space owns Tailscale: it sets accept-dns=false,
      # netfilter-mode=off, and grants CAP_NET_ADMIN/CAP_NET_RAW to the
      # tailscaled unit because the daemon runs inside an nspawn shared
      # netns. The mountainous tailscale feature would overwrite those
      # extraSetFlags with empty defaults, so keep it off here.
      tailscale.enable = false;

      # Upstream modules/ssh.nix runs sshd on :2222 with its own
      # PermitRootLogin=prohibit-password policy. The mountainous ssh
      # feature also enables fail2ban, which needs nftables — and
      # nftables is intentionally disabled inside the guest because
      # nspawn can't initialise the netlink cache without
      # CAP_NET_ADMIN/CAP_NET_RAW being broadly granted. Skip it.
      ssh.server.enable = false;
    };
  };

  # Upstream base.nix already pins system.stateVersion = "25.11" and
  # owns boot.isContainer + nix.gc + journald + time.timeZone, so we do
  # not redeclare them here.
  services.inputplumber.package = lib.mkForce pkgs.inputplumber;
  #
  # boot.isContainer = true pulls in nixpkgs's container-config module,
  # which disables host-only knobs (nix.optimise.automatic, etc.) at the
  # same priority as the mountainous core preset enables them. Force the
  # container-friendly value here so the two mkDefaults don't deadlock.
  nix.optimise.automatic = lib.mkForce false;

  # Non-root deploys (same model as bandai/aka): upstream sshd runs on :2222
  # with PermitRootLogin=no, so nixos-rebuild connects as the korri user and
  # activates via its wheel sudo. The closure-copy step rejects unsigned
  # paths from the build host unless the deploy user is a trusted Nix user.
  nix.settings.trusted-users = [
    "root"
    "korri"
  ];

  # Upstream owns the Tailscale daemon; mountainous only supplies the shared
  # auth key and the equivalent `tailscale up` flags so sobo can reach its
  # remote builders after activation without a browser login.
  services.tailscale = {
    authKeyFile = config.age.secrets.tailscale-authkey.path;
    extraUpFlags = [
      "--accept-dns=false"
      "--netfilter-mode=off"
      "--hostname=sobo"
    ];
  };

  # Upstream Tailscale runs with accept-dns=false, so pin the builder names
  # to their stable tailnet addresses for Nix's root-owned SSH calls.
  networking.extraHosts = ''
    100.69.49.119 fuji fuji.hummingbird-lake.ts.net
    100.90.129.5 yari yari.hummingbird-lake.ts.net
  '';

  # Keep the handheld from compiling locally. Sobo's Nix daemon logs in to the
  # aarch64 servers with a dedicated agenix-managed key and copies build
  # products back to the local store.
  nix = {
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "fuji";
        protocol = "ssh-ng";
        system = "aarch64-linux";
        sshUser = "simonwjackson";
        sshKey = config.age.secrets.nix-builder-ssh-key.path;
        maxJobs = 8;
        speedFactor = 10;
        supportedFeatures = [
          "benchmark"
          "big-parallel"
          "kvm"
          "nixos-test"
        ];
        publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU1LZE5aYjZxbmNTSGNBTEZ4dHpBRENEU0V0KzAzVkxoUlFtTlNuK3JIYTIgcm9vdEBmdWppCg==";
      }
    ];
    settings = {
      builders-use-substitutes = true;
      max-jobs = 0;
    };
  };

  # Kiosk session/autostart comes from services.korri.kiosk defaults supplied
  # by the nix-on-rocks main-space platform module. The client package pin was
  # dropped 2026-07: trunk's korri-client module defaults to the Chromium
  # kiosk renderer package (korri-desktop-device no longer exists).
  services.korri.client.enable = true;

  # The desktop launch bridge tries the `moonlight` binary first; keep it in
  # the Korri kiosk PATH instead of relying on the slower nixpkgs fallback in a
  # sealed device session.
  environment.systemPackages = [pkgs.moonlight-qt];
  services.korri.compositor.path = [
    config.services.korri.client.package
    pkgs.moonlight-qt
  ];
}
