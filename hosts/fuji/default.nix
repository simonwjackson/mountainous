{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "fuji";
  networking.useDHCP = true;
  time.timeZone = "UTC";

  # Transparent x86_64 emulation (needed for SQL Server, etc.)
  boot.binfmt.emulatedSystems = ["x86_64-linux"];

  mountainous = {
    presets = {
      core = {
        enable = true;
        passwordHash = "$6$4gXnXZmsRgERP5JC$0p8F935IKYb3wj0aiaTymqaWS0sJhgyZpu9vO8Q5SIF2hSpRZ7d.hy1JIn7TTbL.zjSScFrrjqq.BI6MZQfjW0";
      };
      server = {
        enable = true;
        signingKeyFile = "/etc/nix/signing-key.priv";
      };
    };

    features = {
      # ── Networking ───────────────────────────────────────────────────
      tsnsrv = {
        enable = true;
        authKeyFile = config.age.secrets.tailscale-authkey.path;
      };
      vpn-ns = {
        enable = true;
        configFile = config.age.secrets."fastest-vpn".path;
        localNetworks = ["100.64.0.0/10"];
      };

      # ── Storage / backup ─────────────────────────────────────────────
      borgbackup = {
        enable = true;
        passphraseFile = config.age.secrets.borg-passphrase.path;
        offsiteSync = {
          enable = true;
          targets = [
            "aka:/tundra/merged/iceberg/backups"
            "yari:/var/lib/borg-mirror"
          ];
        };
        cloudSync.enable = true;
      };

      # ── Sync / scheduled ────────────────────────────────────────────
      biometrics-sync = {
        enable = true;
        oura.enable = true;
        withings.enable = true;
        ketomojo.enable = true;
      };
      omi = {
        enable = true;
        schedule = "*:0/15:00";
      };

      # ── User tools ──────────────────────────────────────────────────
      kroger = {
        enable = true;
        clientIdFile = config.age.secrets.kroger-client-id.path;
        clientSecretFile = config.age.secrets.kroger-client-secret.path;
      };
    };
  };

  # Allow sobo's Nix daemon to use fuji as an aarch64 remote builder without
  # granting it access to any human SSH private key.
  users.users.simonwjackson.openssh.authorizedKeys.keyFiles = [
    ../../secrets/keys/users/id_rsa.pub
    ../../secrets/keys/users/id_ed25519.pub
    ../../secrets/keys/users/sobo_nix_builder_ed25519.pub
  ];

  # Do not bind sshd to a specific Tailscale address at boot. tailscale0 can
  # come up after sshd starts, which leaves the daemon failed after a reboot.
  # The firewall still restricts remote SSH access to trusted Tailscale traffic.

  environment.systemPackages = with pkgs;
    [
      gogcli
      yq
      (python3.withPackages (ps: [ps.pyyaml]))
    ]
    ++ (with pkgs.lifted-scripts; [
      fitness-import
      nutrition-lookup
      nutrition-log-meal
      nutrition-daily-summary
      tasks-query
      ebay-api
      ebay-publish
    ]);

  # ── Secrets (overrides for auto-discovered defaults) ──────────────────

  age.secrets.tailscale-authkey = {
    group = "tsnsrv";
    mode = "0440";
  };

  age.secrets.rclone-conf.path = "/home/simonwjackson/.config/rclone/rclone.conf";

  system.stateVersion = "24.11";
}
