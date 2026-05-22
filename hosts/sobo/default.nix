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
  #
  # boot.isContainer = true pulls in nixpkgs's container-config module,
  # which disables host-only knobs (nix.optimise.automatic, etc.) at the
  # same priority as the mountainous core preset enables them. Force the
  # container-friendly value here so the two mkDefaults don't deadlock.
  nix.optimise.automatic = lib.mkForce false;

  # Korri client package selection remains mountainous-owned, while the
  # product kiosk session/autostart comes from services.korri.kiosk defaults
  # supplied by the nix-on-rocks main-space platform module.
  services.korri.client = {
    enable = true;
    package = inputs.korri.packages.${pkgs.stdenv.hostPlatform.system}.korri-desktop-device;
  };

  # The desktop launch bridge tries the `moonlight` binary first; keep it in
  # the Korri kiosk PATH instead of relying on the slower nixpkgs fallback in a
  # sealed device session.
  environment.systemPackages = [ pkgs.moonlight-qt ];
  services.korri.kiosk.path = [
    config.services.korri.client.package
    pkgs.moonlight-qt
  ];
}
