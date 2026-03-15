{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkAfter
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optional
    optionalAttrs
    recursiveUpdate
    types
    ;

  cfg = config.mountainous.sonarr;
  mediaCfg = config.mountainous.media;
  vpnNsAddress = config.mountainous.vpn-ns.vethAddress;
  nzbgetInVpn = (config.mountainous.vpn-ns.services.nzbget.enable or false);
  transmissionInVpn = (config.mountainous.vpn-ns.services.transmission.enable or false);
  nzbgetHost = if !cfg.vpn.enable && nzbgetInVpn then vpnNsAddress else "127.0.0.1";
  transmissionHost = if !cfg.vpn.enable && transmissionInVpn then vpnNsAddress else "127.0.0.1";
  stateDir = "/var/lib/sonarr";
  dataDir = "${stateDir}/.config/NzbDrone";
  configFile = "${dataDir}/config.xml";
  downloadClientsJson = builtins.toJSON (
    optional cfg.downloadClients.nzbget.enable {
      implementation = "Nzbget";
      name = cfg.downloadClients.nzbget.name;
      priority = cfg.downloadClients.nzbget.priority;
      settings = {
        host = cfg.downloadClients.nzbget.host;
        port = cfg.downloadClients.nzbget.port;
        useSsl = cfg.downloadClients.nzbget.useSsl;
        urlBase = cfg.downloadClients.nzbget.urlBase;
        username = cfg.downloadClients.nzbget.username;
        password = "";
        tvCategory = cfg.downloadClients.nzbget.category;
        recentTvPriority = cfg.downloadClients.nzbget.recentTvPriority;
        olderTvPriority = cfg.downloadClients.nzbget.olderTvPriority;
        addPaused = cfg.downloadClients.nzbget.addPaused;
      };
      secretFields = optionalAttrs (cfg.downloadClients.nzbget.passwordFile != null) {
        password = toString cfg.downloadClients.nzbget.passwordFile;
      };
    }
    ++ optional cfg.downloadClients.transmission.enable {
      implementation = "Transmission";
      name = cfg.downloadClients.transmission.name;
      priority = cfg.downloadClients.transmission.priority;
      settings = {
        host = cfg.downloadClients.transmission.host;
        port = cfg.downloadClients.transmission.port;
        useSsl = cfg.downloadClients.transmission.useSsl;
        urlBase = cfg.downloadClients.transmission.urlBase;
        username = cfg.downloadClients.transmission.username;
        password = "";
        tvCategory = cfg.downloadClients.transmission.category;
        tvImportedCategory = cfg.downloadClients.transmission.importedCategory;
        tvDirectory = cfg.downloadClients.transmission.directory;
        recentTvPriority = cfg.downloadClients.transmission.recentTvPriority;
        olderTvPriority = cfg.downloadClients.transmission.olderTvPriority;
        addPaused = cfg.downloadClients.transmission.addPaused;
      };
      secretFields = optionalAttrs (cfg.downloadClients.transmission.passwordFile != null) {
        password = toString cfg.downloadClients.transmission.passwordFile;
      };
    }
  );
in {
  options.mountainous.sonarr = {
    enable = mkEnableOption "Sonarr with Mountainous defaults";

    user = mkOption {
      type = types.str;
      default = "sonarr";
      description = "User account under which Sonarr runs.";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Primary group for Sonarr; usually the shared media group.";
    };

    port = mkOption {
      type = types.port;
      default = 8989;
      description = "Sonarr web UI and API port.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Sonarr port in the firewall.";
    };

    auth = {
      enable = mkEnableOption "Sonarr web authentication";

      username = mkOption {
        type = types.str;
        default = "simonwjackson";
        description = "Username for Sonarr web authentication.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a secret file containing the Sonarr password.";
      };

      required = mkOption {
        type = types.enum ["Enabled" "DisabledForLocalAddresses"];
        default = "Enabled";
        description = "How broadly Sonarr auth is enforced.";
      };
    };

    vpn.enable = mkEnableOption "run Sonarr inside the VPN namespace";

    proxy = {
      enable = mkEnableOption "expose Sonarr through tsnet-proxy";

      hostname = mkOption {
        type = types.str;
        default = "tv";
        description = "Tailscale hostname for Sonarr.";
      };

      protocol = mkOption {
        type = types.enum ["http" "https"];
        default = "http";
        description = "Backend protocol used by tsnet-proxy.";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open the host firewall for the tsnet-proxy listener.";
      };
    };

    tvLibraryDir = mkOption {
      type = types.str;
      default = mediaCfg.tvDir;
      description = "Shared TV library path Sonarr should manage and import into.";
    };

    usenetCompletedDir = mkOption {
      type = types.str;
      default = mediaCfg.usenetCompletedDir;
      description = "Completed Usenet downloads path Sonarr should import from.";
    };

    torrentsCompletedDir = mkOption {
      type = types.str;
      default = mediaCfg.torrentsCompletedDir;
      description = "Completed torrent downloads path Sonarr should import from.";
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional settings forwarded to services.sonarr.settings.";
      example = {
        server = {
          bindaddress = "*";
          port = 8989;
        };
      };
    };

    downloadClients = {
      nzbget = {
        enable = mkEnableOption "seed NZBGet as a Sonarr download client";

        name = mkOption {
          type = types.str;
          default = "NZBGet";
          description = "Display name for the Sonarr NZBGet download client.";
        };

        priority = mkOption {
          type = types.int;
          default = 10;
          description = "Sonarr priority for this NZBGet client. Lower numbers sort earlier in the UI and are useful when multiple usenet clients exist.";
        };

        host = mkOption {
          type = types.str;
          default = nzbgetHost;
          description = "Host Sonarr should use to reach NZBGet.";
        };

        port = mkOption {
          type = types.port;
          default = config.mountainous.nzbget.port;
          description = "Port Sonarr should use to reach NZBGet.";
        };

        useSsl = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Sonarr should use TLS for NZBGet.";
        };

        urlBase = mkOption {
          type = types.str;
          default = "";
          description = "Optional NZBGet URL base.";
        };

        username = mkOption {
          type = types.str;
          default = config.mountainous.nzbget.controlUsername;
          description = "Username Sonarr should use for NZBGet.";
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Optional secret file containing the NZBGet password for Sonarr.";
        };

        category = mkOption {
          type = types.str;
          default = "Series";
          description = "NZBGet category Sonarr should assign to TV downloads.";
        };

        recentTvPriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Sonarr should send to NZBGet for recent episodes.";
        };

        olderTvPriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Sonarr should send to NZBGet for older episodes.";
        };

        addPaused = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Sonarr should add NZBGet jobs paused.";
        };
      };

      transmission = {
        enable = mkEnableOption "seed Transmission as a Sonarr download client";

        name = mkOption {
          type = types.str;
          default = "Transmission";
          description = "Display name for the Sonarr Transmission download client.";
        };

        priority = mkOption {
          type = types.int;
          default = 20;
          description = "Sonarr priority for this Transmission client. Lower numbers sort earlier in the UI and are useful when multiple torrent clients exist.";
        };

        host = mkOption {
          type = types.str;
          default = transmissionHost;
          description = "Host Sonarr should use to reach Transmission.";
        };

        port = mkOption {
          type = types.port;
          default = config.mountainous.transmission.port;
          description = "Port Sonarr should use to reach Transmission.";
        };

        useSsl = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Sonarr should use TLS for Transmission.";
        };

        urlBase = mkOption {
          type = types.str;
          default = "/transmission/";
          description = "Transmission RPC URL base Sonarr should use.";
        };

        username = mkOption {
          type = types.str;
          default = "";
          description = "Username Sonarr should use for Transmission.";
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Optional secret file containing the Transmission password for Sonarr.";
        };

        category = mkOption {
          type = types.str;
          default = "tv-sonarr";
          description = "Transmission category Sonarr should assign to TV torrents.";
        };

        importedCategory = mkOption {
          type = types.str;
          default = "";
          description = "Optional post-import Transmission category Sonarr should set.";
        };

        directory = mkOption {
          type = types.str;
          default = "";
          description = "Optional per-client download directory override for Transmission.";
        };

        recentTvPriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Sonarr should send to Transmission for recent episodes.";
        };

        olderTvPriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Sonarr should send to Transmission for older episodes.";
        };

        addPaused = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Sonarr should add Transmission torrents paused.";
        };
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions =
        [
          {
            assertion = mediaCfg.enable;
            message = "mountainous.sonarr requires mountainous.media.enable = true";
          }
        ]
        ++ optional cfg.auth.enable {
          assertion = cfg.auth.passwordFile != null;
          message = "mountainous.sonarr requires auth.passwordFile when auth.enable = true";
        }
        ++ optional cfg.vpn.enable {
          assertion = config.mountainous.vpn-ns.enable;
          message = "mountainous.sonarr requires mountainous.vpn-ns.enable = true when vpn.enable = true";
        }
        ++ optional cfg.proxy.enable {
          assertion = config.mountainous.services.tsnet-proxy.enable or false;
          message = "mountainous.sonarr requires mountainous.services.tsnet-proxy.enable = true when proxy.enable = true";
        }
        ++ optional cfg.downloadClients.nzbget.enable {
          assertion = config.mountainous.nzbget.enable;
          message = "mountainous.sonarr.downloadClients.nzbget requires mountainous.nzbget.enable = true";
        }
        ++ optional cfg.downloadClients.transmission.enable {
          assertion = config.mountainous.transmission.enable;
          message = "mountainous.sonarr.downloadClients.transmission requires mountainous.transmission.enable = true";
        };

      services.sonarr = {
        enable = true;
        inherit (cfg) user group;
        dataDir = dataDir;
        settings =
          recursiveUpdate {
            server = {
              bindaddress = "*";
              port = cfg.port;
              urlbase = "";
            };
          }
          cfg.settings;
      };

      systemd.services.sonarr.environment = {
        DOTNET_SYSTEM_NET_HTTP_SOCKETSHTTPHANDLER_HTTP2SUPPORT = "0";
      };

      systemd.services.sonarr.preStart = mkAfter ''
        ${pkgs.python3}/bin/python <<'PY'
        import base64
        import hashlib
        import sqlite3
        import uuid
        import xml.etree.ElementTree as ET
        from pathlib import Path

        auth_enabled = ${
          if cfg.auth.enable
          then "True"
          else "False"
        }
        username = ${builtins.toJSON cfg.auth.username}
        auth_required = ${builtins.toJSON cfg.auth.required}
        password_file = ${builtins.toJSON (
          if cfg.auth.passwordFile == null
          then ""
          else toString cfg.auth.passwordFile
        )}

        config_file = Path(${builtins.toJSON configFile})
        config_file.parent.mkdir(parents=True, exist_ok=True)

        if config_file.exists():
            root = ET.fromstring(config_file.read_text())
        else:
            root = ET.Element("Config")

        def set_value(tag: str, value: str) -> None:
            node = root.find(tag)
            if node is None:
                node = ET.SubElement(root, tag)
            node.text = value

        set_value("BindAddress", "*")
        set_value("Port", str(${toString cfg.port}))
        set_value("UrlBase", "")
        set_value("AuthenticationMethod", "Forms" if auth_enabled else "None")
        set_value("AuthenticationRequired", auth_required if auth_enabled else "DisabledForLocalAddresses")

        if root.find("ApiKey") is None:
            set_value("ApiKey", uuid.uuid4().hex)

        config_file.write_text(ET.tostring(root, encoding="unicode"))

        if auth_enabled:
            password = Path(password_file).read_text().strip()
            db_path = config_file.parent / "sonarr.db"
            db = sqlite3.connect(db_path)
            db.execute(
                "CREATE TABLE IF NOT EXISTS Users (Id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, Identifier TEXT NOT NULL, Username TEXT NOT NULL, Password TEXT NOT NULL, Salt TEXT, Iterations INTEGER)"
            )
            db.execute("CREATE UNIQUE INDEX IF NOT EXISTS IX_Users_Username ON Users (Username ASC)")

            salt_bytes = hashlib.sha256(f"mountainous-sonarr:{username}".encode()).digest()[:16]
            iterations = 10000
            password_hash = hashlib.pbkdf2_hmac("sha512", password.encode(), salt_bytes, iterations, dklen=32)
            identifier = str(uuid.uuid5(uuid.NAMESPACE_URL, f"mountainous-sonarr:{username}"))

            db.execute("DELETE FROM Users")
            db.execute(
                "INSERT INTO Users (Id, Identifier, Username, Password, Salt, Iterations) VALUES (?, ?, ?, ?, ?, ?)",
                (
                    1,
                    identifier,
                    username,
                    base64.b64encode(password_hash).decode(),
                    base64.b64encode(salt_bytes).decode(),
                    iterations,
                ),
            )
            db.commit()
            db.close()
        PY
      '';

      users.users.${cfg.user}.extraGroups = optional (cfg.group != mediaCfg.group) mediaCfg.group;

      systemd.services.sonarr.serviceConfig.BindPaths = mkAfter [
        cfg.tvLibraryDir
        cfg.usenetCompletedDir
        cfg.torrentsCompletedDir
      ];

      systemd.tmpfiles.rules =
        optional (cfg.downloadClients.nzbget.enable && cfg.downloadClients.nzbget.category != "")
        "d '${cfg.usenetCompletedDir}/${cfg.downloadClients.nzbget.category}' 2775 root ${cfg.group} - -"
        ++ optional (cfg.downloadClients.transmission.enable && cfg.downloadClients.transmission.category != "")
        "d '${cfg.torrentsCompletedDir}/${cfg.downloadClients.transmission.category}' 2775 root ${cfg.group} - -";

      systemd.services.sonarr-seed-root-folder = {
        description = "Seed declarative Sonarr root folder";
        after = ["sonarr.service"] ++ optional cfg.vpn.enable "vpn-ns.service";
        requires = ["sonarr.service"] ++ optional cfg.vpn.enable "vpn-ns.service";
        wantedBy = ["multi-user.target"];
        serviceConfig = mkMerge [
          {
            Type = "oneshot";
            RemainAfterExit = true;
          }
          (mkIf cfg.vpn.enable {
            NetworkNamespacePath = "/run/netns/vpn";
            BindReadOnlyPaths = ["/etc/netns/vpn/resolv.conf:/etc/resolv.conf"];
          })
        ];
        script = ''
          ${pkgs.python3}/bin/python <<'PY'
          import json
          import time
          import urllib.error
          import urllib.request
          import xml.etree.ElementTree as ET
          from pathlib import Path

          config_root = ET.fromstring(Path(${builtins.toJSON configFile}).read_text())
          api_key = config_root.findtext("ApiKey")
          if not api_key:
              raise RuntimeError("Sonarr ApiKey missing from config.xml")

          base_url = "http://127.0.0.1:${toString cfg.port}"
          headers = {
              "X-Api-Key": api_key,
              "Content-Type": "application/json",
          }

          def request_json(path, *, method="GET", data=None):
              payload = None if data is None else json.dumps(data).encode()
              request = urllib.request.Request(f"{base_url}{path}", data=payload, headers=headers, method=method)
              try:
                  with urllib.request.urlopen(request, timeout=30) as response:
                      raw = response.read()
                      return None if not raw else json.loads(raw)
              except urllib.error.HTTPError as error:
                  body = error.read().decode()
                  raise RuntimeError(f"Sonarr API {method} {path} failed: {error.code} {body}") from error

          for _ in range(30):
              try:
                  request_json("/api/v3/rootfolder")
                  break
              except Exception:
                  time.sleep(1)
          else:
              raise RuntimeError("Timed out waiting for Sonarr API")

          root_folders = request_json("/api/v3/rootfolder")
          target_path = ${builtins.toJSON cfg.tvLibraryDir}
          if any(root_folder.get("path") == target_path for root_folder in root_folders):
              raise SystemExit(0)

          request_json("/api/v3/rootfolder", method="POST", data={"path": target_path})
          PY
        '';
      };

      systemd.services.sonarr-seed-download-clients = mkIf (cfg.downloadClients.nzbget.enable || cfg.downloadClients.transmission.enable) {
        description = "Seed declarative Sonarr download clients";
        after =
          ["sonarr.service"]
          ++ optional cfg.vpn.enable "vpn-ns.service"
          ++ optional cfg.downloadClients.nzbget.enable "nzbget.service"
          ++ optional cfg.downloadClients.transmission.enable "transmission.service";
        requires =
          ["sonarr.service"]
          ++ optional cfg.vpn.enable "vpn-ns.service"
          ++ optional cfg.downloadClients.nzbget.enable "nzbget.service"
          ++ optional cfg.downloadClients.transmission.enable "transmission.service";
        wantedBy = ["multi-user.target"];
        serviceConfig = mkMerge [
          {
            Type = "oneshot";
            RemainAfterExit = true;
          }
          (mkIf cfg.vpn.enable {
            NetworkNamespacePath = "/run/netns/vpn";
            BindReadOnlyPaths = ["/etc/netns/vpn/resolv.conf:/etc/resolv.conf"];
          })
        ];
        script = ''
          ${pkgs.python3}/bin/python <<'PY'
          import copy
          import json
          import time
          import urllib.error
          import urllib.request
          import xml.etree.ElementTree as ET
          from pathlib import Path

          def read_secret_value(path_str: str) -> str:
              raw = Path(path_str).read_text().strip()
              if "=" in raw:
                  return raw.split("=", 1)[1].strip()
              return raw

          config_root = ET.fromstring(Path(${builtins.toJSON configFile}).read_text())
          api_key = config_root.findtext("ApiKey")
          if not api_key:
              raise RuntimeError("Sonarr ApiKey missing from config.xml")

          desired_clients = json.loads(${builtins.toJSON downloadClientsJson})
          base_url = "http://127.0.0.1:${toString cfg.port}"
          headers = {
              "X-Api-Key": api_key,
              "Content-Type": "application/json",
          }

          def request_json(path, *, method="GET", data=None):
              payload = None if data is None else json.dumps(data).encode()
              request = urllib.request.Request(f"{base_url}{path}", data=payload, headers=headers, method=method)
              try:
                  with urllib.request.urlopen(request, timeout=30) as response:
                      raw = response.read()
                      return None if not raw else json.loads(raw)
              except urllib.error.HTTPError as error:
                  body = error.read().decode()
                  raise RuntimeError(f"Sonarr API {method} {path} failed: {error.code} {body}") from error

          for _ in range(30):
              try:
                  request_json("/api/v3/downloadclient")
                  break
              except Exception:
                  time.sleep(1)
          else:
              raise RuntimeError("Timed out waiting for Sonarr API")

          schema = request_json("/api/v3/downloadclient/schema")
          existing_clients = request_json("/api/v3/downloadclient")

          for spec in desired_clients:
              template = copy.deepcopy(next(item for item in schema if item.get("implementation") == spec["implementation"]))
              template["enable"] = True
              template["name"] = spec["name"]
              template["priority"] = spec["priority"]

              field_values = dict(spec.get("settings", {}))
              for field_name, path in spec.get("secretFields", {}).items():
                  field_values[field_name] = read_secret_value(path)

              for field in template.get("fields", []):
                  if field.get("name") in field_values:
                      field["value"] = field_values[field["name"]]

              existing_client = next(
                  (
                      item
                      for item in existing_clients
                      if item.get("name") == spec["name"] or item.get("implementation") == spec["implementation"]
                  ),
                  None,
              )

              if existing_client is None:
                  created = request_json("/api/v3/downloadclient", method="POST", data=template)
                  existing_clients.append(created)
              else:
                  template["id"] = existing_client["id"]
                  updated = request_json(
                      f"/api/v3/downloadclient/{existing_client['id']}",
                      method="PUT",
                      data=template,
                  )
                  existing_clients = [
                      updated if item.get("id") == existing_client["id"] else item
                      for item in existing_clients
                  ]
          PY
        '';
      };

      networking.firewall.allowedTCPPorts = optional cfg.openFirewall cfg.port;
    }
    (mkIf cfg.vpn.enable {
      mountainous.vpn-ns.services.sonarr =
        {
          enable = true;
          unit = "sonarr.service";
          port = cfg.port;
        }
        // optionalAttrs cfg.proxy.enable {
          tailscale = {
            enable = true;
            hostname = cfg.proxy.hostname;
            protocol = cfg.proxy.protocol;
          };
        };
    })
    (mkIf (!cfg.vpn.enable && cfg.proxy.enable) {
      mountainous.services.tsnet-proxy.services.sonarr = {
        hostname = cfg.proxy.hostname;
        protocol = cfg.proxy.protocol;
        host = "localhost";
        port = cfg.port;
        openFirewall = cfg.proxy.openFirewall;
      };
    })
    (mkIf (cfg.vpn.enable && cfg.proxy.enable) {
      mountainous.services.tsnet-proxy.services.sonarr.openFirewall = cfg.proxy.openFirewall;
    })
  ]);
}
