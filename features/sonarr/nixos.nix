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
    mkForce
    mkIf
    mkMerge
    mkOption
    optional
    optionalAttrs
    recursiveUpdate
    types
    ;

  cfg = config.mountainous.features.sonarr;
  mediaCfg = config.mountainous.features.media;
  vpnNsAddress = config.mountainous.features.vpn-ns.vethAddress;
  nzbgetInVpn = config.mountainous.features.vpn-ns.services.nzbget.enable or false;
  transmissionInVpn = config.mountainous.features.vpn-ns.services.transmission.enable or false;
  nzbgetHost =
    if !cfg.vpn.enable && nzbgetInVpn
    then vpnNsAddress
    else "127.0.0.1";
  transmissionHost =
    if !cfg.vpn.enable && transmissionInVpn
    then vpnNsAddress
    else "127.0.0.1";
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
  config = mkIf cfg.enable (mkMerge [
    {
      assertions =
        [
          {
            assertion = mediaCfg.enable;
            message = "mountainous.features.sonarr requires mountainous.features.media.enable = true";
          }
        ]
        ++ optional cfg.auth.enable {
          assertion = cfg.auth.passwordFile != null;
          message = "mountainous.features.sonarr requires auth.passwordFile when auth.enable = true";
        }
        ++ optional cfg.vpn.enable {
          assertion = config.mountainous.features.vpn-ns.enable;
          message = "mountainous.features.sonarr requires mountainous.features.vpn-ns.enable = true when vpn.enable = true";
        }
        ++ optional cfg.proxy.enable {
          assertion = config.mountainous.features.tsnet-proxy.enable or false;
          message = "mountainous.features.sonarr requires mountainous.features.tsnet-proxy.enable = true when proxy.enable = true";
        }
        ++ optional cfg.downloadClients.nzbget.enable {
          assertion = config.mountainous.features.nzbget.enable;
          message = "mountainous.features.sonarr.downloadClients.nzbget requires mountainous.features.nzbget.enable = true";
        }
        ++ optional cfg.downloadClients.transmission.enable {
          assertion = config.mountainous.features.transmission.enable;
          message = "mountainous.features.sonarr.downloadClients.transmission requires mountainous.features.transmission.enable = true";
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

      systemd.services.sonarr.serviceConfig.UMask = mkForce "0002";

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
          import re
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

          def normalize_name(name: str) -> str:
              return re.sub(r"[^a-z0-9]", "", name.lower())

          for _ in range(30):
              try:
                  request_json("/api/v3/rootfolder")
                  break
              except Exception:
                  time.sleep(1)
          else:
              raise RuntimeError("Timed out waiting for Sonarr API")

          target_path = ${builtins.toJSON cfg.tvLibraryDir}
          root_folders = request_json("/api/v3/rootfolder")
          if not any(root_folder.get("path") == target_path for root_folder in root_folders):
              request_json("/api/v3/rootfolder", method="POST", data={"path": target_path})
              root_folders = request_json("/api/v3/rootfolder")

          target_children = {}
          target_root = Path(target_path)
          if target_root.exists():
              for child in target_root.iterdir():
                  if child.is_dir():
                      target_children.setdefault(normalize_name(child.name), child.name)

          series_list = request_json("/api/v3/series")
          for series in series_list:
              current_root = series.get("rootFolderPath") or ""
              current_path = series.get("path") or ""
              if current_root == target_path and current_path.startswith(f"{target_path}/"):
                  continue

              relative_path = ""
              if current_root and current_path.startswith(f"{current_root.rstrip('/')}/"):
                  relative_path = current_path[len(current_root):].lstrip("/")
              elif current_path:
                  relative_path = Path(current_path).name

              if relative_path:
                  parts = relative_path.split("/", 1)
                  matched_top = target_children.get(normalize_name(parts[0]), parts[0])
                  relative_path = matched_top if len(parts) == 1 else f"{matched_top}/{parts[1]}"
                  series["path"] = f"{target_path}/{relative_path}"
              else:
                  series["path"] = target_path
              series["rootFolderPath"] = target_path
              request_json(f"/api/v3/series/{series['id']}?moveFiles=false", method="PUT", data=series)

          root_folders = request_json("/api/v3/rootfolder")
          referenced_roots = {series.get("rootFolderPath") for series in request_json("/api/v3/series")}
          for root_folder in root_folders:
              root_path = root_folder.get("path")
              if root_path and root_path != target_path and root_path not in referenced_roots:
                  request_json(f"/api/v3/rootfolder/{root_folder['id']}", method="DELETE")
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

      systemd.services.sonarr-seed-notifications = mkIf cfg.notifications.webhookRelay.enable {
        description = "Seed Sonarr webhook notification for Matrix relay";
        after =
          ["sonarr.service"]
          ++ optional cfg.vpn.enable "vpn-ns.service";
        requires =
          ["sonarr.service"]
          ++ optional cfg.vpn.enable "vpn-ns.service";
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
        script = let
          webhookUrl =
            if cfg.notifications.webhookRelay.actionUrl != null
            then "${cfg.notifications.webhookRelay.url}?url=${cfg.notifications.webhookRelay.actionUrl}"
            else cfg.notifications.webhookRelay.url;
        in ''
          ${pkgs.python3}/bin/python <<'PY'
          import copy
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

          # Wait for Sonarr API
          for _ in range(30):
              try:
                  request_json("/api/v3/notification")
                  break
              except Exception:
                  time.sleep(1)
          else:
              raise RuntimeError("Timed out waiting for Sonarr API")

          existing = request_json("/api/v3/notification")
          webhook_url = ${builtins.toJSON webhookUrl}

          # Check if our notification already exists
          existing_notif = next(
              (n for n in existing if n.get("name") == "Matrix Webhook Relay"),
              None,
          )

          # Get the Webhook schema template
          schema = request_json("/api/v3/notification/schema")
          template = copy.deepcopy(
              next(s for s in schema if s.get("implementation") == "Webhook")
          )

          template["enable"] = True
          template["name"] = "Matrix Webhook Relay"
          template["onGrab"] = True
          template["onDownload"] = True
          template["onUpgrade"] = True
          template["onSeriesAdd"] = True
          template["onSeriesDelete"] = True
          template["onHealthIssue"] = True
          template["onHealthRestored"] = False
          template["onApplicationUpdate"] = False
          template["onManualInteractionRequired"] = True
          template["includeHealthWarnings"] = True

          # Set webhook fields
          for field in template.get("fields", []):
              if field.get("name") == "url":
                  field["value"] = webhook_url
              elif field.get("name") == "method":
                  field["value"] = 1  # POST

          if existing_notif is None:
              request_json("/api/v3/notification?forceSave=true", method="POST", data=template)
              print("Created Sonarr notification: Matrix Webhook Relay")
          else:
              template["id"] = existing_notif["id"]
              request_json(
                  f"/api/v3/notification/{existing_notif['id']}?forceSave=true",
                  method="PUT",
                  data=template,
              )
              print("Updated Sonarr notification: Matrix Webhook Relay")
          PY
        '';
      };

      systemd.services.sonarr-seed-jellyfin-notification = mkIf cfg.notifications.jellyfin.enable {
        description = "Seed Sonarr Jellyfin/Emby notification connection";
        after =
          ["sonarr.service"]
          ++ optional cfg.vpn.enable "vpn-ns.service";
        requires =
          ["sonarr.service"]
          ++ optional cfg.vpn.enable "vpn-ns.service";
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

          config_root = ET.fromstring(Path(${builtins.toJSON configFile}).read_text())
          api_key = config_root.findtext("ApiKey")
          if not api_key:
              raise RuntimeError("Sonarr ApiKey missing from config.xml")

          jellyfin_password = Path(${builtins.toJSON cfg.notifications.jellyfin.passwordFile}).read_text().strip()
          if "=" in jellyfin_password:
              jellyfin_password = jellyfin_password.split("=", 1)[1].strip()

          base_url = "http://127.0.0.1:${toString cfg.port}"
          headers = {
              "X-Api-Key": api_key,
              "Content-Type": "application/json",
          }
          jellyfin_base_url = "${
            if cfg.notifications.jellyfin.useSsl
            then "https"
            else "http"
          }://${cfg.notifications.jellyfin.host}:${toString cfg.notifications.jellyfin.port}"

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

          def authenticate_jellyfin():
              auth_header = 'MediaBrowser Client="mountainous", Device="mountainous", DeviceId="sonarr-jellyfin", Version="1.0.0"'
              payload = json.dumps({
                  "Username": ${builtins.toJSON cfg.notifications.jellyfin.username},
                  "Pw": jellyfin_password,
              }).encode()
              request = urllib.request.Request(
                  f"{jellyfin_base_url}/Users/AuthenticateByName",
                  data=payload,
                  headers={
                      "Authorization": auth_header,
                      "Content-Type": "application/json",
                  },
                  method="POST",
              )
              try:
                  with urllib.request.urlopen(request, timeout=30) as response:
                      return json.loads(response.read())["AccessToken"]
              except urllib.error.HTTPError as error:
                  body = error.read().decode()
                  raise RuntimeError(f"Jellyfin authentication failed: {error.code} {body}") from error

          for _ in range(30):
              try:
                  request_json("/api/v3/notification")
                  break
              except Exception:
                  time.sleep(1)
          else:
              raise RuntimeError("Timed out waiting for Sonarr API")

          jellyfin_token = authenticate_jellyfin()

          existing = request_json("/api/v3/notification")
          notification_name = "Jellyfin Library Update"

          existing_notif = next(
              (n for n in existing if n.get("name") == notification_name),
              None,
          )

          schema = request_json("/api/v3/notification/schema")
          template = copy.deepcopy(
              next(s for s in schema if s.get("implementation") == "MediaBrowser")
          )

          template["enable"] = True
          template["name"] = notification_name
          template["onDownload"] = True
          template["onUpgrade"] = True
          template["onRename"] = True
          template["onSeriesAdd"] = False
          template["onSeriesDelete"] = True
          template["onEpisodeFileDelete"] = True
          template["onEpisodeFileDeleteForUpgrade"] = True

          for field in template.get("fields", []):
              if field.get("name") == "host":
                  field["value"] = ${builtins.toJSON cfg.notifications.jellyfin.host}
              elif field.get("name") == "port":
                  field["value"] = ${toString cfg.notifications.jellyfin.port}
              elif field.get("name") == "apiKey":
                  field["value"] = jellyfin_token
              elif field.get("name") == "useSsl":
                  field["value"] = ${
            if cfg.notifications.jellyfin.useSsl
            then "True"
            else "False"
          }

          if existing_notif is None:
              request_json("/api/v3/notification?forceSave=true", method="POST", data=template)
              print(f"Created Sonarr notification: {notification_name}")
          else:
              template["id"] = existing_notif["id"]
              request_json(
                  f"/api/v3/notification/{existing_notif['id']}?forceSave=true",
                  method="PUT",
                  data=template,
              )
              print(f"Updated Sonarr notification: {notification_name}")
          PY
        '';
      };

      networking.firewall.allowedTCPPorts = optional cfg.openFirewall cfg.port;
    }
    (mkIf cfg.vpn.enable {
      mountainous.features.vpn-ns.services.sonarr =
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
      mountainous.features.tsnet-proxy.services.sonarr = {
        hostname = cfg.proxy.hostname;
        protocol = cfg.proxy.protocol;
        host = "localhost";
        port = cfg.port;
        openFirewall = cfg.proxy.openFirewall;
      };
    })
    (mkIf (cfg.vpn.enable && cfg.proxy.enable) {
      mountainous.features.tsnet-proxy.services.sonarr.openFirewall = cfg.proxy.openFirewall;
    })
  ]);
}
