{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    attrByPath
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

  cfg = config.mountainous.features.prowlarr;
  dataDir = "/var/lib/prowlarr";
  configFile = "${dataDir}/config.xml";
  authCredentialEntries = optional cfg.auth.enable "auth-password:${toString cfg.auth.passwordFile}";
  nzbgeekCredentialEntries = optional cfg.indexers.nzbgeek.enable "nzbgeek-api:${toString cfg.indexers.nzbgeek.apiKeyFile}";
  sonarrEnabled = attrByPath ["mountainous" "features" "sonarr" "enable"] false config;
  sonarrPort = attrByPath ["mountainous" "features" "sonarr" "port"] 8989 config;
  sonarrVpnEnabled = attrByPath ["mountainous" "features" "sonarr" "vpn" "enable"] false config;
  sonarrConfigFile = "/var/lib/sonarr/.config/NzbDrone/config.xml";
  radarrEnabled = attrByPath ["mountainous" "features" "radarr" "enable"] false config;
  radarrPort = attrByPath ["mountainous" "features" "radarr" "port"] 7878 config;
  radarrVpnEnabled = attrByPath ["mountainous" "features" "radarr" "vpn" "enable"] false config;
  radarrConfigFile = "/var/lib/radarr/.config/Radarr/config.xml";
  vpnHostAddress = "10.200.200.1";
  vpnNsAddress = config.mountainous.features.vpn-ns.vethAddress;
  sonarrHost =
    if cfg.vpn.enable && !sonarrVpnEnabled
    then vpnHostAddress
    else "127.0.0.1";
  radarrHost =
    if cfg.vpn.enable && !radarrVpnEnabled
    then vpnHostAddress
    else "127.0.0.1";
  prowlarrHostForSonarr =
    if cfg.vpn.enable && !sonarrVpnEnabled
    then vpnNsAddress
    else "127.0.0.1";
  prowlarrHostForRadarr =
    if cfg.vpn.enable && !radarrVpnEnabled
    then vpnNsAddress
    else "127.0.0.1";
  applicationsRunInVpn =
    cfg.vpn.enable
    || (cfg.applications.sonarr.enable && sonarrVpnEnabled)
    || (cfg.applications.radarr.enable && radarrVpnEnabled);
  applicationsJson = builtins.toJSON (
    optional cfg.applications.sonarr.enable {
      implementation = "Sonarr";
      name = cfg.applications.sonarr.name;
      prowlarrUrl = cfg.applications.sonarr.prowlarrUrl;
      baseUrl = cfg.applications.sonarr.baseUrl;
      syncLevel = cfg.applications.sonarr.syncLevel;
      configFile = sonarrConfigFile;
      healthPath = "/api/v3/system/status";
      indexersPath = "/api/v3/indexer";
    }
    ++ optional cfg.applications.radarr.enable {
      implementation = "Radarr";
      name = cfg.applications.radarr.name;
      prowlarrUrl = cfg.applications.radarr.prowlarrUrl;
      baseUrl = cfg.applications.radarr.baseUrl;
      syncLevel = cfg.applications.radarr.syncLevel;
      configFile = radarrConfigFile;
      healthPath = "/api/v3/system/status";
      indexersPath = "/api/v3/indexer";
    }
  );
in {
  config = mkIf cfg.enable (mkMerge [
    {
      assertions =
        []
        ++ optional cfg.auth.enable {
          assertion = cfg.auth.passwordFile != null;
          message = "mountainous.features.prowlarr requires auth.passwordFile when auth.enable = true";
        }
        ++ optional cfg.indexers.nzbgeek.enable {
          assertion = cfg.indexers.nzbgeek.apiKeyFile != null;
          message = "mountainous.features.prowlarr.indexers.nzbgeek requires apiKeyFile when enabled";
        }
        ++ optional cfg.applications.sonarr.enable {
          assertion = sonarrEnabled;
          message = "mountainous.features.prowlarr.applications.sonarr requires mountainous.features.sonarr.enable = true";
        }
        ++ optional cfg.applications.radarr.enable {
          assertion = radarrEnabled;
          message = "mountainous.features.prowlarr.applications.radarr requires mountainous.features.radarr.enable = true";
        }
        ++ optional cfg.vpn.enable {
          assertion = config.mountainous.features.vpn-ns.enable;
          message = "mountainous.features.prowlarr requires mountainous.features.vpn-ns.enable = true when vpn.enable = true";
        }
        ++ optional cfg.proxy.enable {
          assertion = config.mountainous.features.tsnet-proxy.enable or false;
          message = "mountainous.features.prowlarr requires mountainous.features.tsnet-proxy.enable = true when proxy.enable = true";
        };

      services.prowlarr = {
        enable = true;
        inherit (cfg) openFirewall;
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

      systemd.services.prowlarr.serviceConfig = optionalAttrs (authCredentialEntries != []) {
        LoadCredential = authCredentialEntries;
      };

      systemd.services.prowlarr.preStart = mkAfter ''
        ${pkgs.python3}/bin/python <<'PY'
        import base64
        import hashlib
        import os
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

        config_file = Path(${builtins.toJSON configFile})
        config_file.parent.mkdir(parents=True, exist_ok=True)

        def new_config_from_existing(reason: str) -> ET.Element:
            backup = config_file.with_name(f"{config_file.name}.{reason}-{uuid.uuid4().hex}")
            config_file.replace(backup)
            return ET.Element("Config")

        if config_file.exists():
            raw = config_file.read_text()
            if not raw.strip():
                root = new_config_from_existing("empty")
            else:
                try:
                    root = ET.fromstring(raw)
                except ET.ParseError:
                    root = new_config_from_existing("corrupt")
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
            credentials_dir = Path(os.environ["CREDENTIALS_DIRECTORY"])
            password = (credentials_dir / "auth-password").read_text().strip()
            db_path = config_file.parent / "prowlarr.db"
            db = sqlite3.connect(db_path)
            db.execute(
                "CREATE TABLE IF NOT EXISTS Users (Id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, Identifier TEXT NOT NULL, Username TEXT NOT NULL, Password TEXT NOT NULL, Salt TEXT, Iterations INTEGER)"
            )
            db.execute("CREATE UNIQUE INDEX IF NOT EXISTS IX_Users_Username ON Users (Username ASC)")

            salt_bytes = hashlib.sha256(f"mountainous-prowlarr:{username}".encode()).digest()[:16]
            iterations = 10000
            password_hash = hashlib.pbkdf2_hmac("sha512", password.encode(), salt_bytes, iterations, dklen=32)
            identifier = str(uuid.uuid5(uuid.NAMESPACE_URL, f"mountainous-prowlarr:{username}"))

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

      systemd.services.prowlarr-seed-indexers = mkIf cfg.indexers.nzbgeek.enable {
        description = "Seed declarative Prowlarr indexers";
        after = ["prowlarr.service"] ++ optional cfg.vpn.enable "vpn-ns.service";
        requires = ["prowlarr.service"] ++ optional cfg.vpn.enable "vpn-ns.service";
        wantedBy = ["multi-user.target"];
        serviceConfig = mkMerge [
          {
            Type = "oneshot";
            RemainAfterExit = true;
            LoadCredential = nzbgeekCredentialEntries;
          }
          (mkIf cfg.vpn.enable {
            NetworkNamespacePath = "/run/netns/vpn";
            BindReadOnlyPaths = ["/etc/netns/vpn/resolv.conf:/etc/resolv.conf"];
          })
        ];
        script = ''
          ${pkgs.python3}/bin/python <<'PY'
          import json
          import os
          import time
          import urllib.error
          import urllib.request
          import xml.etree.ElementTree as ET
          from pathlib import Path

          credentials_dir = Path(os.environ["CREDENTIALS_DIRECTORY"])
          nzbgeek_api_key = (credentials_dir / "nzbgeek-api").read_text().strip()
          if "=" in nzbgeek_api_key:
              nzbgeek_api_key = nzbgeek_api_key.split("=", 1)[1].strip()

          config_root = ET.fromstring(Path(${builtins.toJSON configFile}).read_text())
          prowlarr_api_key = config_root.findtext("ApiKey")
          if not prowlarr_api_key:
              raise RuntimeError("Prowlarr ApiKey missing from config.xml")

          base_url = "http://127.0.0.1:${toString cfg.port}"
          headers = {
              "X-Api-Key": prowlarr_api_key,
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
                  raise RuntimeError(f"Prowlarr API {method} {path} failed: {error.code} {body}") from error

          for _ in range(30):
              try:
                  app_profiles = request_json("/api/v1/appprofile")
                  break
              except Exception:
                  time.sleep(1)
          else:
              raise RuntimeError("Timed out waiting for Prowlarr API")

          app_profile = next((profile for profile in app_profiles if profile.get("name") == "Standard"), None)
          if app_profile is None and app_profiles:
              app_profile = app_profiles[0]
          if app_profile is None:
              raise RuntimeError("No Prowlarr app profile available for seeding indexers")

          def field_value(item, name):
              for field in item.get("fields", []):
                  if field.get("name") == name:
                      return field.get("value")
              return None

          existing_indexers = request_json("/api/v1/indexer")
          existing = next(
              (
                  indexer
                  for indexer in existing_indexers
                  if indexer.get("name") == ${builtins.toJSON cfg.indexers.nzbgeek.name}
                  or any(url == ${builtins.toJSON cfg.indexers.nzbgeek.baseUrl} for url in indexer.get("indexerUrls", []))
              ),
              None,
          )

          if existing is not None:
              current_matches = (
                  existing.get("enable") is True
                  and existing.get("name") == ${builtins.toJSON cfg.indexers.nzbgeek.name}
                  and existing.get("priority") == ${toString cfg.indexers.nzbgeek.priority}
                  and existing.get("appProfileId") == app_profile["id"]
                  and ${builtins.toJSON cfg.indexers.nzbgeek.baseUrl} in existing.get("indexerUrls", [])
                  and field_value(existing, "apiPath") == ${builtins.toJSON cfg.indexers.nzbgeek.apiPath}
              )
              if current_matches:
                  raise SystemExit(0)

          schema = request_json("/api/v1/indexer/schema")
          nzbgeek_schema = next((item for item in schema if item.get("name") == "NZBgeek"), None)
          if nzbgeek_schema is None:
              raise RuntimeError("Could not find NZBGeek schema in Prowlarr")

          payload = dict(nzbgeek_schema)
          payload["enable"] = True
          payload["name"] = ${builtins.toJSON cfg.indexers.nzbgeek.name}
          payload["priority"] = ${toString cfg.indexers.nzbgeek.priority}
          payload["appProfileId"] = app_profile["id"]

          fields = []
          for field in payload.get("fields", []):
              updated = dict(field)
              if field.get("name") == "baseUrl":
                  updated["value"] = ${builtins.toJSON cfg.indexers.nzbgeek.baseUrl}
              elif field.get("name") == "apiPath":
                  updated["value"] = ${builtins.toJSON cfg.indexers.nzbgeek.apiPath}
              elif field.get("name") == "apiKey":
                  updated["value"] = nzbgeek_api_key
              fields.append(updated)
          payload["fields"] = fields

          if existing is None:
              request_json("/api/v1/indexer", method="POST", data=payload)
          else:
              payload["id"] = existing["id"]
              request_json(f"/api/v1/indexer/{existing['id']}", method="PUT", data=payload)
          PY
        '';
      };

      systemd.services.prowlarr-seed-applications = mkIf (cfg.applications.sonarr.enable || cfg.applications.radarr.enable) {
        description = "Seed declarative Prowlarr applications";
        after =
          ["prowlarr.service"]
          ++ optional cfg.applications.sonarr.enable "sonarr.service"
          ++ optional cfg.applications.radarr.enable "radarr.service"
          ++ optional applicationsRunInVpn "vpn-ns.service";
        requires =
          ["prowlarr.service"]
          ++ optional cfg.applications.sonarr.enable "sonarr.service"
          ++ optional cfg.applications.radarr.enable "radarr.service"
          ++ optional applicationsRunInVpn "vpn-ns.service";
        wantedBy = ["multi-user.target"];
        serviceConfig = mkMerge [
          {
            Type = "oneshot";
            RemainAfterExit = true;
          }
          (mkIf applicationsRunInVpn {
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

          prowlarr_root = ET.fromstring(Path(${builtins.toJSON configFile}).read_text())
          prowlarr_api_key = prowlarr_root.findtext("ApiKey")
          if not prowlarr_api_key:
              raise RuntimeError("Prowlarr ApiKey missing from config.xml")

          desired_applications = json.loads(${builtins.toJSON applicationsJson})
          prowlarr_base_url = "http://127.0.0.1:${toString cfg.port}"
          prowlarr_headers = {
              "X-Api-Key": prowlarr_api_key,
              "Content-Type": "application/json",
          }

          def request_json(base_url, path, headers, *, method="GET", data=None):
              payload = None if data is None else json.dumps(data).encode()
              request = urllib.request.Request(f"{base_url}{path}", data=payload, headers=headers, method=method)
              try:
                  with urllib.request.urlopen(request, timeout=30) as response:
                      raw = response.read()
                      return None if not raw else json.loads(raw)
              except urllib.error.HTTPError as error:
                  body = error.read().decode()
                  raise RuntimeError(f"Request {method} {base_url}{path} failed: {error.code} {body}") from error

          app_headers = {}
          for app in desired_applications:
              app_root = ET.fromstring(Path(app["configFile"]).read_text())
              app_api_key = app_root.findtext("ApiKey")
              if not app_api_key:
                  raise RuntimeError(f"{app['implementation']} ApiKey missing from {app['configFile']}")
              app_headers[app["implementation"]] = {
                  "X-Api-Key": app_api_key,
                  "Content-Type": "application/json",
              }

          for _ in range(30):
              try:
                  request_json(prowlarr_base_url, "/api/v1/applications/schema", prowlarr_headers)
                  for app in desired_applications:
                      request_json(app["baseUrl"], app["healthPath"], app_headers[app["implementation"]])
                  break
              except Exception:
                  time.sleep(1)
          else:
              raise RuntimeError("Timed out waiting for Prowlarr and managed application APIs")

          schema = request_json(prowlarr_base_url, "/api/v1/applications/schema", prowlarr_headers)
          existing_applications = request_json(prowlarr_base_url, "/api/v1/applications", prowlarr_headers)

          for app in desired_applications:
              app_schema = next((item for item in schema if item.get("implementation") == app["implementation"]), None)
              if app_schema is None:
                  raise RuntimeError(f"Could not find {app['implementation']} application schema in Prowlarr")

              payload = dict(app_schema)
              payload["enable"] = True
              payload["name"] = app["name"]
              payload["syncLevel"] = app["syncLevel"]

              fields = []
              for field in payload.get("fields", []):
                  updated = dict(field)
                  if field.get("name") == "prowlarrUrl":
                      updated["value"] = app["prowlarrUrl"]
                  elif field.get("name") == "baseUrl":
                      updated["value"] = app["baseUrl"]
                  elif field.get("name") == "apiKey":
                      updated["value"] = app_headers[app["implementation"]]["X-Api-Key"]
                  fields.append(updated)
              payload["fields"] = fields

              existing = next(
                  (
                      application
                      for application in existing_applications
                      if application.get("implementation") == app["implementation"]
                      or application.get("name") == app["name"]
                  ),
                  None,
              )

              if existing is None:
                  created = request_json(prowlarr_base_url, "/api/v1/applications", prowlarr_headers, method="POST", data=payload)
                  existing_applications.append(created)
              else:
                  payload["id"] = existing["id"]
                  updated = request_json(
                      prowlarr_base_url,
                      f"/api/v1/applications/{existing['id']}",
                      prowlarr_headers,
                      method="PUT",
                      data=payload,
                  )
                  existing_applications = [
                      updated if application.get("id") == existing["id"] else application
                      for application in existing_applications
                  ]

              # Prowlarr's proxied indexer entries in downstream apps must use
              # Prowlarr's own API key. If Prowlarr rotates its API key, the
              # synced Sonarr/Radarr indexer entries can keep a stale key and
              # start failing with 401 Unauthorized until they are rewritten.
              app_indexers = request_json(app["baseUrl"], app["indexersPath"], app_headers[app["implementation"]])
              prowlarr_prefix = app["prowlarrUrl"].rstrip("/") + "/"
              for indexer in app_indexers:
                  fields = indexer.get("fields") or []
                  base_url_field = next((field for field in fields if field.get("name") == "baseUrl"), None)
                  api_key_field = next((field for field in fields if field.get("name") == "apiKey"), None)
                  if base_url_field is None or api_key_field is None:
                      continue

                  indexer_base_url = (base_url_field.get("value") or "").rstrip("/") + "/"
                  if not indexer_base_url.startswith(prowlarr_prefix):
                      continue

                  if api_key_field.get("value") == prowlarr_api_key:
                      continue

                  api_key_field["value"] = prowlarr_api_key
                  request_json(
                      app["baseUrl"],
                      f"{app['indexersPath']}/{indexer['id']}",
                      app_headers[app["implementation"]],
                      method="PUT",
                      data=indexer,
                  )
          PY
        '';
      };
    }
    (mkIf cfg.vpn.enable {
      mountainous.features.vpn-ns.services.prowlarr =
        {
          enable = true;
          unit = "prowlarr.service";
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
      mountainous.features.tsnet-proxy.services.prowlarr = {
        hostname = cfg.proxy.hostname;
        protocol = cfg.proxy.protocol;
        host = "localhost";
        port = cfg.port;
        openFirewall = cfg.proxy.openFirewall;
      };
    })
    (mkIf (cfg.vpn.enable && cfg.proxy.enable) {
      mountainous.features.tsnet-proxy.services.prowlarr.openFirewall = cfg.proxy.openFirewall;
    })
  ]);
}
