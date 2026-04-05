{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.matrix;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.matrix = {
    enable = mkEnableOption "Matrix homeserver with Mountainous defaults";

    serverName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Matrix server name (appears in user IDs like @user:serverName).";
    };

    port = mkOption {
      type = types.port;
      default = 8008;
      description = "Port for the Synapse client API listener.";
    };

    admin = {
      username = mkOption {
        type = types.str;
        default = "admin";
        description = "Admin username to create on the homeserver.";
      };

      passwordFile = mkOption {
        type = types.path;
        description = "Path to a file containing the admin user's password.";
      };
    };

    registrationSharedSecretFile = mkOption {
      type = types.path;
      description = ''
        Path to a file containing the registration_shared_secret for Synapse.
        Used to register the admin user declaratively.
      '';
    };

    backup = {
      enable = mkEnableOption "borg backup of Matrix state";

      passphraseFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to borg passphrase file. If null, uses the borgbackup feature's passphraseFile.";
      };

      repoPath = mkOption {
        type = types.str;
        default = "/var/lib/borg/matrix";
        description = "Local borg repository path for Matrix backups.";
      };

      startAt = mkOption {
        type = types.str;
        default = "daily";
        description = "Systemd calendar expression for backup schedule.";
      };

      cloudSync = {
        enable = mkEnableOption "sync Matrix borg repo to cloud storage";

        schedule = mkOption {
          type = types.str;
          default = "*-*-* 04:30:00";
          description = "Systemd OnCalendar expression for cloud sync.";
        };

        remotes = mkOption {
          type = types.listOf types.str;
          default = ["dropbox" "gdrive"];
          description = "rclone remote names to sync to.";
        };

        rcloneConfigFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to rclone config file (agenix secret).";
        };
      };
    };

    proxy = {
      enable = mkEnableOption "expose Matrix through tsnet-proxy";

      hostname = mkOption {
        type = types.str;
        default = "matrix";
        description = "Tailscale hostname for Matrix.";
      };
    };

    notifications = {
      enable = mkEnableOption "notification room and bot account for service alerts";

      roomAlias = mkOption {
        type = types.str;
        default = "notifications";
        description = "Local alias for the notifications room (becomes #alias:serverName).";
      };

      roomName = mkOption {
        type = types.str;
        default = "Notifications";
        description = "Display name for the notifications room.";
      };

      bot = {
        username = mkOption {
          type = types.str;
          default = "notify-bot";
          description = "Username for the notification bot account.";
        };

        passwordFile = mkOption {
          type = types.path;
          description = "Path to a file containing the bot user's password.";
        };
      };

      tokenPath = mkOption {
        type = types.str;
        default = "/var/lib/matrix-notifications/bot-token";
        readOnly = true;
        description = ''
          Path where the bot's access token is written at runtime.
          Other services (e.g., the webhook relay) read from this path.
        '';
      };

      webhookRelay = {
        enable = mkEnableOption "HTTP webhook to Matrix relay service";

        port = mkOption {
          type = types.port;
          default = 9100;
          description = "Port for the webhook relay HTTP server.";
        };

        bind = mkOption {
          type = types.str;
          default = "0.0.0.0";
          description = ''
            Address to bind the webhook relay to.
            Default 0.0.0.0 makes it reachable from vpn-ns veth peers.
          '';
        };
      };

      systemdAlerts = {
        enable = mkEnableOption "send Matrix notifications when critical systemd services fail";

        services = mkOption {
          type = types.listOf types.str;
          default = [];
          example = ["matrix-synapse" "sonarr" "radarr" "nzbget" "borgbackup-job-matrix"];
          description = ''
            Systemd service names to attach OnFailure= notifications to.
            When any of these services fail, a high-priority message is
            posted to the Matrix notifications room via the webhook relay.
          '';
        };
      };
    };

    extraUsers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          passwordFile = mkOption {
            type = types.path;
            description = "Path to a file containing the user's password.";
          };

          admin = mkOption {
            type = types.bool;
            default = false;
            description = "Whether this user should be a server admin.";
          };
        };
      });
      default = {};
      example = {
        openclaw = {
          passwordFile = "/run/agenix/openclaw-matrix-pass";
          admin = false;
        };
      };
      description = ''
        Additional Matrix users to register on the homeserver.
        Each user is created idempotently via the Synapse admin registration API.
      '';
    };

    bridges = {
      signal = {
        enable = mkEnableOption "Signal bridge (mautrix-signal)";

        environmentFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Environment file for mautrix-signal secrets.
            Should contain ENCRYPTION_PICKLE_KEY=<value>.
          '';
        };
      };

      whatsapp = {
        enable = mkEnableOption "WhatsApp bridge (mautrix-whatsapp)";

        environmentFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            Environment file for mautrix-whatsapp secrets.
            Should contain ENCRYPTION_PICKLE_KEY=<value>.
          '';
        };
      };
    };
  };
}
