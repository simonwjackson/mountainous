{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) attrByPath concatStringsSep mkIf mkMerge optional;
  cfg = config.mountainous.features.jellyswarrm;
  tsnetProxyEnabled = attrByPath ["mountainous" "features" "tsnet-proxy" "enable"] false config;
  dataDir = "/var/lib/jellyswarrm";

  # Generate the preconfigured_servers TOML fragment
  serverToToml = s: ''
    [[preconfigured_servers]]
    url = "${s.url}"
    name = "${s.name}"
    priority = ${toString s.priority}
    media_streaming_mode = "${s.streamingMode}"
  '';

  configToml = pkgs.writeText "jellyswarrm.toml" ''
    host = "0.0.0.0"
    port = ${toString cfg.port}
    server_name = "${cfg.serverName}"
    username = "${cfg.username}"
    auto_create_users_on_login = true
    media_streaming_mode = "Proxy"

    ${concatStringsSep "\n" (map serverToToml cfg.servers)}
  '';
in {
  config = mkIf cfg.enable (mkMerge [
    {
      assertions =
        []
        ++ optional cfg.proxy.enable {
          assertion = tsnetProxyEnabled;
          message = "mountainous.features.jellyswarrm.proxy requires mountainous.features.tsnet-proxy.enable = true";
        }
        ++ optional cfg.bootstrap.enable {
          assertion = cfg.bootstrap.passwordFile != null;
          message = "mountainous.features.jellyswarrm.bootstrap requires bootstrap.passwordFile";
        };

      users.users.jellyswarrm = {
        isSystemUser = true;
        group = "jellyswarrm";
        home = dataDir;
        createHome = true;
        description = "Jellyswarrm service user";
      };

      users.groups.jellyswarrm = {};

      systemd.services.jellyswarrm = {
        description = "Jellyswarrm Jellyfin reverse proxy";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];

        environment = {
          JELLYSWARRM_DATA_DIR = dataDir;
        };

        serviceConfig = {
          Type = "simple";
          User = "jellyswarrm";
          Group = "jellyswarrm";
          WorkingDirectory = dataDir;
          Restart = "on-failure";
          RestartSec = "5s";

          # Security hardening
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [dataDir];
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
          RestrictNamespaces = true;
          LockPersonality = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          RemoveIPC = true;
          PrivateMounts = true;
        } // (
          if cfg.passwordFile != null
          then {
            LoadCredential = "password:${cfg.passwordFile}";
            ExecStart = ''${pkgs.bash}/bin/bash -c 'password=$(cat "$CREDENTIALS_DIRECTORY/password"); if [[ "$password" == *=* ]]; then password=$(printf "%s" "$password" | cut -d= -f2-); fi; export JELLYSWARRM_PASSWORD="$password"; exec ${pkgs.jellyswarrm}/bin/jellyswarrm-proxy' '';
          }
          else {
            ExecStart = "${pkgs.jellyswarrm}/bin/jellyswarrm-proxy";
          }
        );

        # Seed the TOML config on first start. Subsequent starts use the
        # existing file so that runtime changes (session_key, server_id)
        # are preserved.  preconfigured_servers are only inserted into the
        # SQLite DB when they don't already exist, so this is idempotent.
        preStart = ''
          if [ ! -f "${dataDir}/jellyswarrm.toml" ]; then
            cp ${configToml} "${dataDir}/jellyswarrm.toml"
          fi
        '';
      };

      systemd.services.jellyswarrm-bootstrap-user = mkIf cfg.bootstrap.enable {
        description = "Bootstrap Jellyswarrm user mappings";
        after = ["jellyswarrm.service"];
        requires = ["jellyswarrm.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          LoadCredential = "password:${cfg.bootstrap.passwordFile}";
        };
        script = let
          serverUrls = map (s: s.url) cfg.servers;
          serverUrlsJson = builtins.toJSON serverUrls;
        in ''
          ${pkgs.python3}/bin/python <<'PY'
          import json
          import os
          import time
          import urllib.error
          import urllib.request
          from pathlib import Path

          bootstrap_username = ${builtins.toJSON cfg.bootstrap.username}
          server_urls = json.loads(${builtins.toJSON serverUrlsJson})
          credentials_dir = Path(os.environ["CREDENTIALS_DIRECTORY"])
          password = (credentials_dir / "password").read_text().strip()
          if "=" in password:
              password = password.split("=", 1)[1].strip()

          def post_json(url, payload, headers=None):
              req = urllib.request.Request(
                  url,
                  data=json.dumps(payload).encode(),
                  headers={"Content-Type": "application/json", **(headers or {})},
                  method="POST",
              )
              with urllib.request.urlopen(req, timeout=30) as resp:
                  return resp.status, resp.read().decode()

          def get_ok(url):
              req = urllib.request.Request(url, headers={"Accept": "application/json"})
              with urllib.request.urlopen(req, timeout=10) as resp:
                  return resp.status == 200

          # Wait for Jellyswarrm itself
          for _ in range(60):
              try:
                  if get_ok("http://127.0.0.1:${toString cfg.port}/System/Info/Public"):
                      break
              except Exception:
                  pass
              time.sleep(2)
          else:
              raise RuntimeError("Timed out waiting for Jellyswarrm API")

          # Wait until all configured backend Jellyfin servers are healthy so the
          # first login creates mappings for all of them, not just a subset.
          deadline = time.time() + 300
          while True:
              all_ok = True
              for server_url in server_urls:
                  try:
                      if not get_ok(server_url.rstrip("/") + "/System/Info/Public"):
                          all_ok = False
                          break
                  except Exception:
                      all_ok = False
                      break
              if all_ok:
                  break
              if time.time() > deadline:
                  raise RuntimeError("Timed out waiting for all Jellyswarrm backend servers to become healthy")
              time.sleep(5)

          auth_header = 'MediaBrowser Client="mountainous-jellyswarrm-bootstrap", Device="mountainous-jellyswarrm-bootstrap", DeviceId="mountainous-jellyswarrm-bootstrap", Version="1.0.0"'
          status, _body = post_json(
              "http://127.0.0.1:${toString cfg.port}/Users/AuthenticateByName",
              {"Username": bootstrap_username, "Pw": password},
              headers={"Authorization": auth_header, "Accept": "application/json"},
          )
          if status != 200:
              raise RuntimeError(f"Jellyswarrm bootstrap login failed with status {status}")
          PY
        '';
      };

      networking.firewall = mkIf cfg.openFirewall {
        allowedTCPPorts = [cfg.port];
      };
    }

    (mkIf cfg.proxy.enable {
      mountainous.features.tsnet-proxy.services.jellyswarrm = {
        host = "127.0.0.1";
        hostname = cfg.proxy.hostname;
        openFirewall = cfg.proxy.openFirewall;
        port = cfg.port;
        protocol = cfg.proxy.protocol;
      };
    })
  ]);
}
