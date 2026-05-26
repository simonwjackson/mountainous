{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) attrByPath mkIf mkMerge optional;
  cfg = config.mountainous.features.matrix;
  tsnetProxyEnabled = attrByPath ["mountainous" "features" "tsnet-proxy" "enable"] false config;
in {
  config = mkIf cfg.enable (mkMerge [
    # ── Synapse homeserver ───────────────────────────────────────────────
    {
      # olm is used by mautrix bridges for end-to-bridge encryption.
      # It is deprecated upstream but still required; permit it until
      # vodozemac replaces it in the bridge ecosystem.
      nixpkgs.config.permittedInsecurePackages = [
        "olm-3.2.16"
      ];

      services.matrix-synapse = {
        enable = true;
        settings = {
          server_name = cfg.serverName;

          listeners = [
            {
              port = cfg.port;
              bind_addresses = ["::1" "127.0.0.1"];
              type = "http";
              tls = false;
              x_forwarded = false;
              resources = [
                {
                  names = ["client" "federation"];
                  compress = true;
                }
              ];
            }
          ];

          # SQLite for MVP simplicity — no postgresql dependency
          database = {
            name = "sqlite3";
            args.database = "/var/lib/matrix-synapse/homeserver.db";
          };

          enable_registration = false;
          suppress_key_server_warning = true;
          report_stats = false;
        };

        # Pass the registration shared secret out-of-store so we can
        # register the admin user without leaking it to the Nix store.
        extraConfigFiles = [
          "/run/matrix-synapse/shared-secret.yaml"
        ];
      };

      # Build the shared-secret yaml from the agenix-decrypted secret
      # before Synapse starts.
      systemd.services.matrix-synapse-shared-secret = {
        description = "Generate Synapse registration_shared_secret config";
        before = ["matrix-synapse.service"];
        requiredBy = ["matrix-synapse.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "matrix-synapse";
          RuntimeDirectoryMode = "0750";
          User = "root";
          Group = "matrix-synapse";
        };
        script = ''
          secret=$(cat ${cfg.registrationSharedSecretFile})
          printf 'registration_shared_secret: "%s"\n' "$secret" \
            > /run/matrix-synapse/shared-secret.yaml
          chown root:matrix-synapse /run/matrix-synapse/shared-secret.yaml
          chmod 640 /run/matrix-synapse/shared-secret.yaml
        '';
      };

      # Register the admin user idempotently after Synapse is ready.
      systemd.services.matrix-synapse-ensure-admin = {
        description = "Ensure Matrix admin user exists";
        after = ["matrix-synapse.service"];
        wants = ["matrix-synapse.service"];
        wantedBy = ["multi-user.target"];
        unitConfig.ConditionPathExists = "/var/lib/matrix-synapse/homeserver.db";
        path = [pkgs.curl pkgs.jq];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "root";
        };
        script = let
          username = cfg.admin.username;
          serverName = cfg.serverName;
          port = toString cfg.port;
        in ''
          # Wait for Synapse to be ready
          for i in $(seq 1 30); do
            if curl -sf http://localhost:${port}/_matrix/client/versions > /dev/null 2>&1; then
              break
            fi
            sleep 1
          done

          SHARED_SECRET=$(cat ${cfg.registrationSharedSecretFile})
          PASSWORD=$(cat ${cfg.admin.passwordFile})

          # Get a nonce
          NONCE=$(curl -s http://localhost:${port}/_synapse/admin/v1/register \
            | jq -r '.nonce')

          if [ -z "$NONCE" ] || [ "$NONCE" = "null" ]; then
            echo "Failed to get registration nonce"
            exit 1
          fi

          # Generate HMAC — Synapse expects: nonce\0username\0password\0admin|notadmin
          MAC=$(printf '%s\0%s\0%s\0%s' \
            "$NONCE" "${username}" "$PASSWORD" "admin" \
            | ${pkgs.openssl}/bin/openssl sha1 -hmac "$SHARED_SECRET" \
            | sed 's/^.* //')

          # Attempt registration
          RESULT=$(curl -s -X POST http://localhost:${port}/_synapse/admin/v1/register \
            -H 'Content-Type: application/json' \
            -d "{
              \"nonce\": \"$NONCE\",
              \"username\": \"${username}\",
              \"password\": \"$PASSWORD\",
              \"admin\": true,
              \"mac\": \"$MAC\"
            }" 2>&1)

          if echo "$RESULT" | jq -e '.user_id' > /dev/null 2>&1; then
            echo "Admin user @${username}:${serverName} created successfully"
          elif echo "$RESULT" | jq -e '.errcode == "M_USER_IN_USE"' > /dev/null 2>&1; then
            echo "Admin user @${username}:${serverName} already exists — OK"
          else
            echo "Unexpected registration result: $RESULT"
            exit 1
          fi
        '';
      };
    }

    # ── Backup ────────────────────────────────────────────────────────
    (mkIf cfg.backup.enable {
      services.borgbackup.jobs.matrix = {
        paths = [
          "/var/lib/matrix-synapse"
          "/var/lib/mautrix-signal"
          "/var/lib/mautrix-whatsapp"
        ];
        repo = cfg.backup.repoPath;
        encryption = {
          mode = "repokey";
          passCommand = "cat ${cfg.backup.passphraseFile}";
        };
        compression = "auto,zstd";
        startAt = cfg.backup.startAt;
        prune.keep = {
          daily = 7;
          weekly = 4;
          monthly = 6;
        };

        # Stop services before backup for SQLite consistency
        preHook = ''
          systemctl stop mautrix-signal.service mautrix-whatsapp.service || true
        '';
        postHook = ''
          systemctl start mautrix-signal.service mautrix-whatsapp.service || true
        '';
      };
    })

    # ── Cloud sync ────────────────────────────────────────────────────
    (mkIf (cfg.backup.enable && cfg.backup.cloudSync.enable) {
      systemd.services.matrix-backup-cloud-sync = {
        description = "Sync Matrix borg repo to cloud storage";
        after = ["borgbackup-job-matrix.service"];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        path = [pkgs.rclone];
        script = let
          hostname = config.networking.hostName;
          rcloneConf =
            lib.optionalString (cfg.backup.cloudSync.rcloneConfigFile != null)
            "--config ${cfg.backup.cloudSync.rcloneConfigFile}";
          syncLines =
            lib.concatMapStringsSep "\n" (remote: ''
              echo "Syncing to ${remote}..."
              rclone sync ${rcloneConf} "${cfg.backup.repoPath}/" "${remote}:backups/${hostname}/matrix/" --transfers 4 --checkers 8 || true
            '')
            cfg.backup.cloudSync.remotes;
        in
          syncLines;
      };

      systemd.timers.matrix-backup-cloud-sync = {
        description = "Cloud sync of Matrix borg repo";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = cfg.backup.cloudSync.schedule;
          Persistent = true;
        };
      };
    })

    # ── Tailscale proxy ─────────────────────────────────────────────────
    (mkIf cfg.proxy.enable {
      assertions = optional cfg.proxy.enable {
        assertion = tsnetProxyEnabled;
        message = "mountainous.features.matrix requires mountainous.features.tsnet-proxy.enable = true when proxy.enable = true";
      };

      mountainous.features.tsnet-proxy.services.matrix = {
        host = "127.0.0.1";
        hostname = cfg.proxy.hostname;
        openFirewall = false;
        port = cfg.port;
        protocol = "http";
      };
    })

    # ── Extra users ──────────────────────────────────────────────────────
    (mkIf (cfg.extraUsers != {}) {
      systemd.services = lib.mapAttrs' (username: userCfg:
        lib.nameValuePair "matrix-synapse-ensure-user-${username}" {
          description = "Ensure Matrix user @${username}:${cfg.serverName} exists";
          after = ["matrix-synapse-ensure-admin.service"];
          wants = ["matrix-synapse-ensure-admin.service"];
          wantedBy = ["multi-user.target"];
          unitConfig.ConditionPathExists = "/var/lib/matrix-synapse/homeserver.db";
          path = [pkgs.curl pkgs.jq pkgs.openssl];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "root";
          };
          script = let
            port = toString cfg.port;
            serverName = cfg.serverName;
            adminFlag =
              if userCfg.admin
              then "admin"
              else "notadmin";
          in ''
            set -euo pipefail

            # Wait for Synapse to be ready
            for i in $(seq 1 30); do
              if curl -sf http://localhost:${port}/_matrix/client/versions > /dev/null 2>&1; then
                break
              fi
              sleep 1
            done

            SHARED_SECRET=$(cat ${cfg.registrationSharedSecretFile})
            PASSWORD=$(cat ${userCfg.passwordFile})

            NONCE=$(curl -s http://localhost:${port}/_synapse/admin/v1/register \
              | jq -r '.nonce')

            if [ -z "$NONCE" ] || [ "$NONCE" = "null" ]; then
              echo "Failed to get registration nonce"
              exit 1
            fi

            MAC=$(printf '%s\0%s\0%s\0%s' \
              "$NONCE" "${username}" "$PASSWORD" "${adminFlag}" \
              | openssl sha1 -hmac "$SHARED_SECRET" \
              | sed 's/^.* //')

            RESULT=$(curl -s -X POST http://localhost:${port}/_synapse/admin/v1/register \
              -H 'Content-Type: application/json' \
              -d "{
                \"nonce\": \"$NONCE\",
                \"username\": \"${username}\",
                \"password\": \"$PASSWORD\",
                \"admin\": ${
              if userCfg.admin
              then "true"
              else "false"
            },
                \"mac\": \"$MAC\"
              }" 2>&1)

            if echo "$RESULT" | jq -e '.user_id' > /dev/null 2>&1; then
              echo "User @${username}:${serverName} created successfully"
            elif echo "$RESULT" | jq -e '.errcode == "M_USER_IN_USE"' > /dev/null 2>&1; then
              echo "User @${username}:${serverName} already exists — OK"
            else
              echo "Unexpected registration result: $RESULT"
              exit 1
            fi
          '';
        })
      cfg.extraUsers;
    })

    # ── Notifications room & bot ─────────────────────────────────────────
    (mkIf cfg.notifications.enable {
      systemd.tmpfiles.rules = [
        "d /var/lib/matrix-notifications 0750 root matrix-synapse - -"
      ];

      systemd.services.matrix-synapse-ensure-notifications = {
        description = "Ensure Matrix notification room and bot exist";
        after = ["matrix-synapse-ensure-admin.service"];
        wants = ["matrix-synapse-ensure-admin.service"];
        wantedBy = ["multi-user.target"];
        unitConfig.ConditionPathExists = "/var/lib/matrix-synapse/homeserver.db";
        path = [pkgs.curl pkgs.jq pkgs.openssl];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "root";
        };
        script = let
          port = toString cfg.port;
          serverName = cfg.serverName;
          adminUsername = cfg.admin.username;
          botUsername = cfg.notifications.bot.username;
          roomAlias = cfg.notifications.roomAlias;
          roomName = cfg.notifications.roomName;
          tokenFile = cfg.notifications.tokenPath;
        in ''
          set -euo pipefail

          # Wait for Synapse to be ready
          for i in $(seq 1 30); do
            if curl -sf http://localhost:${port}/_matrix/client/versions > /dev/null 2>&1; then
              break
            fi
            sleep 1
          done

          SHARED_SECRET=$(cat ${cfg.registrationSharedSecretFile})
          BOT_PASSWORD=$(cat ${cfg.notifications.bot.passwordFile})

          # ── 1. Register bot user (idempotent) ──────────────────────────

          NONCE=$(curl -s http://localhost:${port}/_synapse/admin/v1/register \
            | jq -r '.nonce')

          if [ -z "$NONCE" ] || [ "$NONCE" = "null" ]; then
            echo "Failed to get registration nonce"
            exit 1
          fi

          MAC=$(printf '%s\0%s\0%s\0%s' \
            "$NONCE" "${botUsername}" "$BOT_PASSWORD" "notadmin" \
            | openssl sha1 -hmac "$SHARED_SECRET" \
            | sed 's/^.* //')

          REG_RESULT=$(curl -s -X POST http://localhost:${port}/_synapse/admin/v1/register \
            -H 'Content-Type: application/json' \
            -d "{
              \"nonce\": \"$NONCE\",
              \"username\": \"${botUsername}\",
              \"password\": \"$BOT_PASSWORD\",
              \"admin\": false,
              \"mac\": \"$MAC\"
            }" 2>&1)

          BOT_TOKEN=$(echo "$REG_RESULT" | jq -r '.access_token // empty')

          if echo "$REG_RESULT" | jq -e '.user_id' > /dev/null 2>&1; then
            echo "Bot @${botUsername}:${serverName} created"
          elif echo "$REG_RESULT" | jq -e '.errcode == "M_USER_IN_USE"' > /dev/null 2>&1; then
            echo "Bot @${botUsername}:${serverName} already exists"
            BOT_TOKEN=""
          else
            echo "Bot registration failed: $REG_RESULT"
            exit 1
          fi

          # If registration didn't return a token, login to get one.
          # Use a fixed device_id to avoid accumulating sessions across reboots.
          if [ -z "$BOT_TOKEN" ]; then
            LOGIN_RESULT=$(curl -s -X POST http://localhost:${port}/_matrix/client/v3/login \
              -H 'Content-Type: application/json' \
              -d "{
                \"type\": \"m.login.password\",
                \"identifier\": {\"type\": \"m.id.user\", \"user\": \"${botUsername}\"},
                \"password\": \"$BOT_PASSWORD\",
                \"device_id\": \"NOTIFY_BOT_SERVICE\"
              }")
            BOT_TOKEN=$(echo "$LOGIN_RESULT" | jq -r '.access_token // empty')
            if [ -z "$BOT_TOKEN" ]; then
              echo "Bot login failed: $LOGIN_RESULT"
              exit 1
            fi
          fi

          # Save bot token for the webhook relay
          echo "$BOT_TOKEN" > ${tokenFile}
          chmod 640 ${tokenFile}
          chown root:matrix-synapse ${tokenFile}
          echo "Bot access token saved to ${tokenFile}"

          # ── 2. Create notifications room (idempotent) ──────────────────

          # Login as admin to create the room (admin is the room owner)
          ADMIN_PASSWORD=$(cat ${cfg.admin.passwordFile})
          ADMIN_LOGIN=$(curl -s -X POST http://localhost:${port}/_matrix/client/v3/login \
            -H 'Content-Type: application/json' \
            -d "{
              \"type\": \"m.login.password\",
              \"identifier\": {\"type\": \"m.id.user\", \"user\": \"${adminUsername}\"},
              \"password\": \"$ADMIN_PASSWORD\",
              \"device_id\": \"ADMIN_SETUP_SERVICE\"
            }")
          ADMIN_TOKEN=$(echo "$ADMIN_LOGIN" | jq -r '.access_token // empty')
          if [ -z "$ADMIN_TOKEN" ]; then
            echo "Admin login failed: $ADMIN_LOGIN"
            exit 1
          fi

          # Check if room alias already exists
          ENCODED_ALIAS=$(printf '%s' "#${roomAlias}:${serverName}" | jq -sRr @uri)
          ROOM_CHECK=$(curl -s \
            "http://localhost:${port}/_matrix/client/v3/directory/room/$ENCODED_ALIAS" \
            -H "Authorization: Bearer $ADMIN_TOKEN")
          ROOM_ID=$(echo "$ROOM_CHECK" | jq -r '.room_id // empty')

          if [ -n "$ROOM_ID" ]; then
            echo "Room #${roomAlias}:${serverName} already exists ($ROOM_ID)"
          else
            # Create room: private, unencrypted, invite bot
            CREATE_RESULT=$(curl -s -X POST \
              "http://localhost:${port}/_matrix/client/v3/createRoom" \
              -H "Authorization: Bearer $ADMIN_TOKEN" \
              -H 'Content-Type: application/json' \
              -d "{
                \"room_alias_name\": \"${roomAlias}\",
                \"name\": \"${roomName}\",
                \"topic\": \"Service alerts and system notifications\",
                \"visibility\": \"private\",
                \"preset\": \"private_chat\",
                \"invite\": [\"@${botUsername}:${serverName}\"]
              }")
            ROOM_ID=$(echo "$CREATE_RESULT" | jq -r '.room_id // empty')
            if [ -z "$ROOM_ID" ]; then
              echo "Room creation failed: $CREATE_RESULT"
              exit 1
            fi
            echo "Created #${roomAlias}:${serverName} ($ROOM_ID)"
          fi

          # ── 3. Ensure bot has joined the room ──────────────────────────

          ENCODED_ROOM=$(printf '%s' "$ROOM_ID" | jq -sRr @uri)
          JOIN_RESULT=$(curl -s -X POST \
            "http://localhost:${port}/_matrix/client/v3/join/$ENCODED_ROOM" \
            -H "Authorization: Bearer $BOT_TOKEN" \
            -H 'Content-Type: application/json' \
            -d '{}')

          if echo "$JOIN_RESULT" | jq -e '.room_id' > /dev/null 2>&1; then
            echo "Bot joined $ROOM_ID"
          else
            echo "Bot join result: $JOIN_RESULT"
          fi

          echo "Notification setup complete"
        '';
      };
    })

    # ── Webhook relay ────────────────────────────────────────────────────
    (mkIf (cfg.notifications.enable && cfg.notifications.webhookRelay.enable) {
      systemd.services.matrix-webhook-relay = {
        description = "HTTP webhook to Matrix notification relay";
        after = ["matrix-synapse-ensure-notifications.service" "network.target"];
        requires = ["matrix-synapse-ensure-notifications.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          ExecStart = let
            roomRef = "#${cfg.notifications.roomAlias}:${cfg.serverName}";
          in ''
            ${pkgs.matrix-webhook-relay}/bin/matrix-webhook-relay \
              --homeserver http://localhost:${toString cfg.port} \
              --room "${roomRef}" \
              --token-file ${cfg.notifications.tokenPath} \
              --port ${toString cfg.notifications.webhookRelay.port} \
              --bind ${cfg.notifications.webhookRelay.bind}
          '';
          Restart = "on-failure";
          RestartSec = 5;
          # Run as a dedicated dynamic user for isolation; only needs
          # read access to the bot token file written by the ensure-
          # notifications oneshot.
          DynamicUser = true;
          SupplementaryGroups = ["matrix-synapse"];
          # Hardening
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
          ReadOnlyPaths = [cfg.notifications.tokenPath];
        };
      };

      networking.firewall.allowedTCPPorts =
        optional (cfg.notifications.webhookRelay.bind == "0.0.0.0")
        cfg.notifications.webhookRelay.port;
    })

    # ── Systemd failure alerts ───────────────────────────────────────────
    (mkIf (cfg.notifications.enable && cfg.notifications.systemdAlerts.enable) (let
      notifyScript = pkgs.writeShellScript "notify-matrix-failure" ''
        UNIT="$1"
        HOST=$(${pkgs.hostname}/bin/hostname)
        exec ${pkgs.curl}/bin/curl -sf -X POST \
          "http://127.0.0.1:${toString cfg.notifications.webhookRelay.port}/hook" \
          -H 'Content-Type: application/json' \
          -d "{\"title\":\"Service Failed\",\"body\":\"$UNIT on $HOST\",\"priority\":\"high\"}"
      '';
    in {
      assertions = [
        {
          assertion = cfg.notifications.webhookRelay.enable;
          message = "mountainous.features.matrix.notifications.systemdAlerts requires webhookRelay.enable = true";
        }
      ];

      systemd.services = mkMerge [
        {
          "notify-matrix-failure@" = {
            description = "Send Matrix notification for failed service %i";
            # No After/Requires — this must run even if other services are down.
            # The webhook relay is long-running and should already be up.
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${notifyScript} %i";
            };
          };
        }
        (lib.genAttrs cfg.notifications.systemdAlerts.services (name: {
          unitConfig.OnFailure = ["notify-matrix-failure@%n.service"];
        }))
      ];
    }))

    # ── WhatsApp bridge ─────────────────────────────────────────────────
    (mkIf cfg.bridges.whatsapp.enable {
      services.mautrix-whatsapp = {
        enable = true;
        environmentFile = cfg.bridges.whatsapp.environmentFile;
        settings = {
          homeserver = {
            address = "http://localhost:${toString cfg.port}";
            domain = cfg.serverName;
          };

          bridge = {
            permissions = {
              "@${cfg.admin.username}:${cfg.serverName}" = "admin";
              "${cfg.serverName}" = "user";
            };
          };

          encryption = {
            allow = true;
            default = true;
            pickle_key = "$ENCRYPTION_PICKLE_KEY";
          };
        };
      };
    })

    # ── Signal bridge ────────────────────────────────────────────────────
    (mkIf cfg.bridges.signal.enable {
      services.mautrix-signal = {
        enable = true;
        environmentFile = cfg.bridges.signal.environmentFile;
        settings = {
          homeserver = {
            address = "http://localhost:${toString cfg.port}";
            domain = cfg.serverName;
          };

          bridge = {
            permissions = {
              # Allow the admin user full access
              "@${cfg.admin.username}:${cfg.serverName}" = "admin";
              # Allow all local users to use the bridge
              "${cfg.serverName}" = "user";
            };
          };

          # End-to-bridge encryption — pickle_key is injected via
          # environmentFile so it survives restarts.
          encryption = {
            allow = true;
            default = true;
            pickle_key = "$ENCRYPTION_PICKLE_KEY";
          };
        };
      };
    })
  ]);
}
