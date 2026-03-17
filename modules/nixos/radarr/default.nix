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

  cfg = config.mountainous.radarr;
  mediaCfg = config.mountainous.features.media;
  vpnNsAddress = config.mountainous.features.vpn-ns.vethAddress;
  nzbgetInVpn = (config.mountainous.features.vpn-ns.services.nzbget.enable or false);
  transmissionInVpn = (config.mountainous.features.vpn-ns.services.transmission.enable or false);
  nzbgetHost = if !cfg.vpn.enable && nzbgetInVpn then vpnNsAddress else "127.0.0.1";
  transmissionHost = if !cfg.vpn.enable && transmissionInVpn then vpnNsAddress else "127.0.0.1";
  stateDir = "/var/lib/radarr";
  dataDir = "${stateDir}/.config/Radarr";
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
        movieCategory = cfg.downloadClients.nzbget.category;
        recentMoviePriority = cfg.downloadClients.nzbget.recentMoviePriority;
        olderMoviePriority = cfg.downloadClients.nzbget.olderMoviePriority;
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
        movieCategory = cfg.downloadClients.transmission.category;
        movieImportedCategory = cfg.downloadClients.transmission.importedCategory;
        movieDirectory = cfg.downloadClients.transmission.directory;
        recentMoviePriority = cfg.downloadClients.transmission.recentMoviePriority;
        olderMoviePriority = cfg.downloadClients.transmission.olderMoviePriority;
        addPaused = cfg.downloadClients.transmission.addPaused;
      };
      secretFields = optionalAttrs (cfg.downloadClients.transmission.passwordFile != null) {
        password = toString cfg.downloadClients.transmission.passwordFile;
      };
    }
  );
in {
  options.mountainous.radarr = {
    enable = mkEnableOption "Radarr with Mountainous defaults";

    user = mkOption {
      type = types.str;
      default = "radarr";
      description = "User account under which Radarr runs.";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Primary group for Radarr; usually the shared media group.";
    };

    port = mkOption {
      type = types.port;
      default = 7878;
      description = "Radarr web UI and API port.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Radarr port in the firewall.";
    };

    auth = {
      enable = mkEnableOption "Radarr web authentication";

      username = mkOption {
        type = types.str;
        default = "simonwjackson";
        description = "Username for Radarr web authentication.";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a secret file containing the Radarr password.";
      };

      required = mkOption {
        type = types.enum ["Enabled" "DisabledForLocalAddresses"];
        default = "Enabled";
        description = "How broadly Radarr auth is enforced.";
      };
    };

    vpn.enable = mkEnableOption "run Radarr inside the VPN namespace";

    proxy = {
      enable = mkEnableOption "expose Radarr through tsnet-proxy";

      hostname = mkOption {
        type = types.str;
        default = "movies";
        description = "Tailscale hostname for Radarr.";
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

    moviesLibraryDir = mkOption {
      type = types.str;
      default = mediaCfg.moviesDir;
      description = "Shared movies library path Radarr should manage and import into.";
    };

    usenetCompletedDir = mkOption {
      type = types.str;
      default = mediaCfg.usenetCompletedDir;
      description = "Completed Usenet downloads path Radarr should import from.";
    };

    torrentsCompletedDir = mkOption {
      type = types.str;
      default = mediaCfg.torrentsCompletedDir;
      description = "Completed torrent downloads path Radarr should import from.";
    };

    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional settings forwarded to services.radarr.settings.";
      example = {
        server = {
          bindaddress = "*";
          port = 7878;
        };
      };
    };

    downloadClients = {
      nzbget = {
        enable = mkEnableOption "seed NZBGet as a Radarr download client";

        name = mkOption {
          type = types.str;
          default = "NZBGet";
          description = "Display name for the Radarr NZBGet download client.";
        };

        priority = mkOption {
          type = types.int;
          default = 10;
          description = "Radarr priority for this NZBGet client. Lower numbers sort earlier in the UI and are useful when multiple usenet clients exist.";
        };

        host = mkOption {
          type = types.str;
          default = nzbgetHost;
          description = "Host Radarr should use to reach NZBGet.";
        };

        port = mkOption {
          type = types.port;
          default = config.mountainous.features.nzbget.port;
          description = "Port Radarr should use to reach NZBGet.";
        };

        useSsl = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Radarr should use TLS for NZBGet.";
        };

        urlBase = mkOption {
          type = types.str;
          default = "";
          description = "Optional NZBGet URL base.";
        };

        username = mkOption {
          type = types.str;
          default = config.mountainous.features.nzbget.controlUsername;
          description = "Username Radarr should use for NZBGet.";
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Optional secret file containing the NZBGet password for Radarr.";
        };

        category = mkOption {
          type = types.str;
          default = "Movies";
          description = "NZBGet category Radarr should assign to movie downloads.";
        };

        recentMoviePriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Radarr should send to NZBGet for recent movies.";
        };

        olderMoviePriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Radarr should send to NZBGet for older movies.";
        };

        addPaused = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Radarr should add NZBGet jobs paused.";
        };
      };

      transmission = {
        enable = mkEnableOption "seed Transmission as a Radarr download client";

        name = mkOption {
          type = types.str;
          default = "Transmission";
          description = "Display name for the Radarr Transmission download client.";
        };

        priority = mkOption {
          type = types.int;
          default = 20;
          description = "Radarr priority for this Transmission client. Lower numbers sort earlier in the UI and are useful when multiple torrent clients exist.";
        };

        host = mkOption {
          type = types.str;
          default = transmissionHost;
          description = "Host Radarr should use to reach Transmission.";
        };

        port = mkOption {
          type = types.port;
          default = config.mountainous.features.transmission.port;
          description = "Port Radarr should use to reach Transmission.";
        };

        useSsl = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Radarr should use TLS for Transmission.";
        };

        urlBase = mkOption {
          type = types.str;
          default = "/transmission/";
          description = "Transmission RPC URL base Radarr should use.";
        };

        username = mkOption {
          type = types.str;
          default = "";
          description = "Username Radarr should use for Transmission.";
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Optional secret file containing the Transmission password for Radarr.";
        };

        category = mkOption {
          type = types.str;
          default = "movies-radarr";
          description = "Transmission category Radarr should assign to movie torrents.";
        };

        importedCategory = mkOption {
          type = types.str;
          default = "";
          description = "Optional post-import Transmission category Radarr should set.";
        };

        directory = mkOption {
          type = types.str;
          default = "";
          description = "Optional per-client download directory override for Transmission.";
        };

        recentMoviePriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Radarr should send to Transmission for recent movies.";
        };

        olderMoviePriority = mkOption {
          type = types.int;
          default = 0;
          description = "Priority Radarr should send to Transmission for older movies.";
        };

        addPaused = mkOption {
          type = types.bool;
          default = false;
          description = "Whether Radarr should add Transmission torrents paused.";
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
            message = "mountainous.radarr requires mountainous.features.media.enable = true";
          }
        ]
        ++ optional cfg.auth.enable {
          assertion = cfg.auth.passwordFile != null;
          message = "mountainous.radarr requires auth.passwordFile when auth.enable = true";
        }
        ++ optional cfg.vpn.enable {
          assertion = config.mountainous.features.vpn-ns.enable;
          message = "mountainous.radarr requires mountainous.features.vpn-ns.enable = true when vpn.enable = true";
        }
        ++ optional cfg.proxy.enable {
          assertion = config.mountainous.features.tsnet-proxy.enable or false;
          message = "mountainous.radarr requires mountainous.features.tsnet-proxy.enable = true when proxy.enable = true";
        }
        ++ optional cfg.downloadClients.nzbget.enable {
          assertion = config.mountainous.features.nzbget.enable;
          message = "mountainous.radarr.downloadClients.nzbget requires mountainous.features.nzbget.enable = true";
        }
        ++ optional cfg.downloadClients.transmission.enable {
          assertion = config.mountainous.features.transmission.enable;
          message = "mountainous.radarr.downloadClients.transmission requires mountainous.features.transmission.enable = true";
        };

      services.radarr = {
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

      systemd.services.radarr.preStart = mkAfter ''
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

        if root.find("ApiKey") is None or not (root.findtext("ApiKey") or "").strip():
            set_value("ApiKey", uuid.uuid4().hex)

        config_file.write_text(ET.tostring(root, encoding="unicode"))

        if auth_enabled:
            db_path = config_file.parent / "radarr.db"
            if not db_path.exists():
                raise SystemExit(0)

            db = sqlite3.connect(db_path)
            users_table = db.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'Users'"
            ).fetchone()
            if users_table is None:
                db.close()
                raise SystemExit(0)

            password = Path(password_file).read_text().strip()
            salt_bytes = hashlib.sha256(f"mountainous-radarr:{username}".encode()).digest()[:16]
            iterations = 10000
            password_hash = hashlib.pbkdf2_hmac("sha512", password.encode(), salt_bytes, iterations, dklen=32)
            identifier = str(uuid.uuid5(uuid.NAMESPACE_URL, f"mountainous-radarr:{username}"))

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

      systemd.services.radarr-seed-auth = mkIf cfg.auth.enable {
        description = "Seed declarative Radarr auth user";
        after = ["radarr.service"] ++ optional cfg.vpn.enable "vpn-ns.service";
        requires = ["radarr.service"] ++ optional cfg.vpn.enable "vpn-ns.service";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        } // optionalAttrs cfg.vpn.enable {
          NetworkNamespacePath = "/run/netns/vpn";
          BindReadOnlyPaths = ["/etc/netns/vpn/resolv.conf:/etc/resolv.conf"];
        };
        script = ''
          ${pkgs.python3}/bin/python <<'PY'
          import base64
          import hashlib
          import sqlite3
          import time
          import uuid
          from pathlib import Path

          username = ${builtins.toJSON cfg.auth.username}
          password_file = ${builtins.toJSON (
            if cfg.auth.passwordFile == null
            then ""
            else toString cfg.auth.passwordFile
          )}
          db_path = Path(${builtins.toJSON "${dataDir}/radarr.db"})

          for _ in range(30):
              if db_path.exists():
                  db = sqlite3.connect(db_path)
                  users_table = db.execute(
                      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'Users'"
                  ).fetchone()
                  if users_table is not None:
                      break
                  db.close()
              time.sleep(1)
          else:
              raise RuntimeError("Timed out waiting for Radarr Users table")

          password = Path(password_file).read_text().strip()
          salt_bytes = hashlib.sha256(f"mountainous-radarr:{username}".encode()).digest()[:16]
          iterations = 10000
          password_hash = hashlib.pbkdf2_hmac("sha512", password.encode(), salt_bytes, iterations, dklen=32)
          identifier = str(uuid.uuid5(uuid.NAMESPACE_URL, f"mountainous-radarr:{username}"))

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
      };

      systemd.services.radarr.serviceConfig.BindPaths = mkAfter [
        cfg.moviesLibraryDir
        cfg.usenetCompletedDir
        cfg.torrentsCompletedDir
      ];

      systemd.tmpfiles.rules =
        optional (cfg.downloadClients.nzbget.enable && cfg.downloadClients.nzbget.category != "")
        "d '${cfg.usenetCompletedDir}/${cfg.downloadClients.nzbget.category}' 2775 root ${cfg.group} - -"
        ++ optional (cfg.downloadClients.transmission.enable && cfg.downloadClients.transmission.category != "")
        "d '${cfg.torrentsCompletedDir}/${cfg.downloadClients.transmission.category}' 2775 root ${cfg.group} - -";

      systemd.services.radarr-seed-root-folder = {
        description = "Seed declarative Radarr root folder";
        after = ["radarr.service"] ++ optional cfg.vpn.enable "vpn-ns.service";
        requires = ["radarr.service"] ++ optional cfg.vpn.enable "vpn-ns.service";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        } // optionalAttrs cfg.vpn.enable {
          NetworkNamespacePath = "/run/netns/vpn";
          BindReadOnlyPaths = ["/etc/netns/vpn/resolv.conf:/etc/resolv.conf"];
        };
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
              raise RuntimeError("Radarr ApiKey missing from config.xml")

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
                  raise RuntimeError(f"Radarr API {method} {path} failed: {error.code} {body}") from error

          for _ in range(30):
              try:
                  request_json("/api/v3/rootfolder")
                  break
              except Exception:
                  time.sleep(1)
          else:
              raise RuntimeError("Timed out waiting for Radarr API")

          root_folders = request_json("/api/v3/rootfolder")
          target_path = ${builtins.toJSON cfg.moviesLibraryDir}
          if any(root_folder.get("path") == target_path for root_folder in root_folders):
              raise SystemExit(0)

          request_json("/api/v3/rootfolder", method="POST", data={"path": target_path})
          PY
        '';
      };

      systemd.services.radarr-seed-download-clients = mkIf (cfg.downloadClients.nzbget.enable || cfg.downloadClients.transmission.enable) {
        description = "Seed declarative Radarr download clients";
        after =
          ["radarr.service"]
          ++ optional cfg.vpn.enable "vpn-ns.service"
          ++ optional cfg.downloadClients.nzbget.enable "nzbget.service"
          ++ optional cfg.downloadClients.transmission.enable "transmission.service";
        requires =
          ["radarr.service"]
          ++ optional cfg.vpn.enable "vpn-ns.service"
          ++ optional cfg.downloadClients.nzbget.enable "nzbget.service"
          ++ optional cfg.downloadClients.transmission.enable "transmission.service";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        } // optionalAttrs cfg.vpn.enable {
          NetworkNamespacePath = "/run/netns/vpn";
          BindReadOnlyPaths = ["/etc/netns/vpn/resolv.conf:/etc/resolv.conf"];
        };
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
              raise RuntimeError("Radarr ApiKey missing from config.xml")

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
                  raise RuntimeError(f"Radarr API {method} {path} failed: {error.code} {body}") from error

          for _ in range(30):
              try:
                  request_json("/api/v3/downloadclient")
                  break
              except Exception:
                  time.sleep(1)
          else:
              raise RuntimeError("Timed out waiting for Radarr API")

          schema = request_json("/api/v3/downloadclient/schema")
          existing_clients = request_json("/api/v3/downloadclient")

          def normalize_value(value):
              if isinstance(value, list):
                  return [normalize_value(item) for item in value]
              if isinstance(value, dict):
                  return {key: normalize_value(item) for key, item in sorted(value.items())}
              return value

          def client_matches(existing_client, spec, field_values):
              if existing_client.get("implementation") != spec["implementation"]:
                  return False
              if existing_client.get("name") != spec["name"]:
                  return False
              if existing_client.get("enable") is not True:
                  return False
              if existing_client.get("priority") != spec["priority"]:
                  return False

              existing_fields = {
                  field.get("name"): normalize_value(field.get("value"))
                  for field in existing_client.get("fields", [])
                  if field.get("name") is not None
              }
              secret_field_names = set(spec.get("secretFields", {}).keys())

              for field_name, expected_value in field_values.items():
                  current_value = existing_fields.get(field_name)
                  expected_value = normalize_value(expected_value)

                  if field_name in secret_field_names and current_value in (None, ""):
                      continue

                  if current_value != expected_value:
                      return False

              return True

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
                  (item for item in existing_clients if item.get("name") == spec["name"]),
                  None,
              )

              if existing_client is None:
                  created = request_json("/api/v3/downloadclient", method="POST", data=template)
                  existing_clients.append(created)
              elif client_matches(existing_client, spec, field_values):
                  continue
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
      mountainous.features.vpn-ns.services.radarr =
        {
          enable = true;
          unit = "radarr.service";
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
      mountainous.features.tsnet-proxy.services.radarr = {
        hostname = cfg.proxy.hostname;
        protocol = cfg.proxy.protocol;
        host = "localhost";
        port = cfg.port;
        openFirewall = cfg.proxy.openFirewall;
      };
    })
    (mkIf (cfg.vpn.enable && cfg.proxy.enable) {
      mountainous.features.tsnet-proxy.services.radarr.openFirewall = cfg.proxy.openFirewall;
    })
  ]);
}
