{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ./disko.nix
    ../../modules/server
  ];

  home-manager.users.simonwjackson = import ../../home/simonwjackson;

  networking.hostName = "yari";
  networking.useDHCP = true;
  time.timeZone = "UTC";

  users.users.simonwjackson = {
    isNormalUser = true;
    shell = pkgs.nushell;
    extraGroups = [ "wheel" ];
    hashedPassword = "$6$2Kj4v9kellv./s7d$NkKiUruNiNPDtFJSwsTCIaTGLZ9hf1Yak64FXzFL2ZBMTiQDFW3RcEzOwCCezYOXC7b3UrxmEGbAw/TPehWKv1";
  };

  # ── SSH (Tailscale-only) ─────────────────────────────────────────────

  # Do not bind sshd to a specific Tailscale address at boot. tailscale0 can
  # come up after sshd starts, which leaves the daemon failed after a reboot.
  # The firewall still restricts remote SSH access to trusted Tailscale traffic.

  # ── Security ─────────────────────────────────────────────────────────

  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      maxtime = "168h";
    };
  };

  networking.firewall = {
    enable = true;
    # Default: block everything on public interfaces
    allowedTCPPorts = [];
    allowedUDPPorts = [ 41641 ];  # Tailscale WireGuard (needed on all interfaces)
    # Trust all Tailscale traffic
    trustedInterfaces = [ "tailscale0" ];
  };

  # ── Packages ─────────────────────────────────────────────────────────

  environment.systemPackages = with pkgs; [
    chromium
    stdenv.cc.cc.lib
    nodejs
    git
    curl
    cmake
    gnumake
    gcc
  ];

  # ── Secrets ──────────────────────────────────────────────────────────

  age.secrets.tailscale-authkey = {
    file = ../../secrets/tailscale-authkey.age;
    mode = "0440";
  };

  age.secrets."fastest-vpn" = {
    file = ../../secrets/fastest-vpn.age;
    mode = "0400";
  };

  age.secrets.openclaw-env = {
    file = ../../secrets/openclaw-env.age;
    mode = "0400";
    owner = "simonwjackson";
  };

  # ── Tailscale ────────────────────────────────────────────────────────

  mountainous.tailscale = {
    authKeyFile = config.age.secrets.tailscale-authkey.path;
    extraSetFlags = ["--netfilter-mode=nodivert"];
  };

  # ── VPN Namespace ────────────────────────────────────────────────────

  systemd.services.vpn-ns = {
    description = "VPN Network Namespace";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "notify";
      NotifyAccess = "all";
      ExecStart = "${pkgs.vpn-ns}/bin/vpn-ns --setup";
      ExecStop = "${pkgs.vpn-ns}/bin/vpn-ns --cleanup";
      Restart = "always";
      RestartSec = "10s";
    };
    environment = {
      VPN_NS_CONFIG = config.age.secrets."fastest-vpn".path;
      VPN_NS_LOCAL_NETS = "100.64.0.0/10";
    };
  };

  # ── OpenClaw Node ────────────────────────────────────────────────────

  systemd.services.openclaw-node = {
    description = "OpenClaw Node Host";
    after = [ "network-online.target" "tailscale.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.nodejs pkgs.git pkgs.curl pkgs.chromium pkgs.coreutils pkgs.bash pkgs.cmake pkgs.gnumake pkgs.gcc ];
    environment = {
      HOME = "/home/simonwjackson";
      OPENCLAW_STATE_DIR = "/home/simonwjackson/.openclaw";
      LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
    };
    serviceConfig = {
      Type = "simple";
      User = "simonwjackson";
      Group = "users";
      TimeoutStartSec = "30min";
      EnvironmentFile = config.age.secrets.openclaw-env.path;
      ExecStartPre = let
        setupScript = pkgs.writeShellScript "openclaw-node-setup" ''
          export HOME=/home/simonwjackson
          mkdir -p "$HOME/.openclaw"
          cd "$HOME/.openclaw"
          ${pkgs.nodejs}/bin/npm install openclaw@latest
        '';
      in "${setupScript}";
      ExecStart = let
        startScript = pkgs.writeShellScript "openclaw-node-start" ''
          export HOME=/home/simonwjackson
          exec ${pkgs.nodejs}/bin/node "$HOME/.openclaw/node_modules/openclaw/dist/index.js" node run \
            --host openclaw.hummingbird-lake.ts.net \
            --port 443 \
            --tls \
            --display-name yari
        '';
      in "${startScript}";
      Restart = "always";
      RestartSec = 10;
      KillMode = "process";
    };
  };

  # Trust fuji's signing key for remote deployments
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "fuji-1:0mnvKZa4ZzMJgSgFfQLdQzwcdUtiGqZxxcImE/i9wDo="
  ];

  system.stateVersion = "24.11";
}
