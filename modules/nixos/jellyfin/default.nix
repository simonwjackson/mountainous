{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) attrByPath mkAfter mkEnableOption mkIf mkMerge mkOption optional types;

  cfg = config.mountainous.jellyfin;
  mediaCfg = config.mountainous.features.media;
  tsnetProxyEnabled = attrByPath ["mountainous" "features" "tsnet-proxy" "enable"] false config;
  jellyfinConfigDir = config.services.jellyfin.configDir;
  systemConfigFile = "${jellyfinConfigDir}/system.xml";
  networkConfigFile = "${jellyfinConfigDir}/network.xml";
  bootstrapCredentialEntries = optional (cfg.bootstrap.enable && cfg.bootstrap.admin.passwordFile != null) "bootstrap-password:${toString cfg.bootstrap.admin.passwordFile}";
in {
  options.mountainous.jellyfin = {
    enable = mkEnableOption "Jellyfin with Mountainous defaults";

    user = mkOption {
      type = types.str;
      default = "jellyfin";
      description = "User account under which Jellyfin runs.";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Primary group for Jellyfin; usually the shared media group.";
    };

    port = mkOption {
      type = types.port;
      default = 8096;
      description = "Jellyfin web UI and API port.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Jellyfin port in the firewall.";
    };

    moviesLibraryDir = mkOption {
      type = types.str;
      default = mediaCfg.moviesDir;
      description = "Shared movies library path Jellyfin should expose.";
    };

    tvLibraryDir = mkOption {
      type = types.str;
      default = mediaCfg.tvDir;
      description = "Shared TV library path Jellyfin should expose.";
    };

    bootstrap = {
      enable = mkEnableOption "seed Jellyfin first-run state declaratively";

      admin = {
        username = mkOption {
          type = types.str;
          default = "admin";
          description = "Initial Jellyfin admin username to create during bootstrap.";
        };

        passwordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to a secret file containing the initial Jellyfin admin password.";
        };
      };

      serverName = mkOption {
        type = types.str;
        default = config.networking.hostName;
        description = "Server name to set through Jellyfin's startup wizard API.";
      };

      remoteAccess = mkOption {
        type = types.bool;
        default = false;
        description = "Whether Jellyfin remote access should be enabled during bootstrap.";
      };

      libraries = {
        tv = {
          name = mkOption {
            type = types.str;
            default = "TV";
            description = "Display name for the initial Jellyfin TV library.";
          };

          path = mkOption {
            type = types.str;
            default = cfg.tvLibraryDir;
            description = "Filesystem path for the initial Jellyfin TV library.";
          };
        };

        movies = {
          name = mkOption {
            type = types.str;
            default = "Movies";
            description = "Display name for the initial Jellyfin movies library.";
          };

          path = mkOption {
            type = types.str;
            default = cfg.moviesLibraryDir;
            description = "Filesystem path for the initial Jellyfin movies library.";
          };
        };
      };
    };

    proxy = {
      enable = mkEnableOption "expose Jellyfin through tsnet-proxy";

      hostname = mkOption {
        type = types.str;
        default = "jellyfin";
        description = "Tailscale hostname for Jellyfin.";
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

    watchedCleaner = {
      enable = mkEnableOption "automatic deletion of media watched beyond a configurable age";

      maxAgeDays = mkOption {
        type = types.int;
        default = 7;
        description = "Number of days after an item was last played before it becomes eligible for automatic deletion.";
      };

      interval = mkOption {
        type = types.str;
        default = "daily";
        description = "Systemd calendar expression controlling how often the cleaner runs.";
      };

      mediaTypes = mkOption {
        type = types.listOf (types.enum ["Movie" "Episode"]);
        default = ["Movie" "Episode"];
        description = "Jellyfin media types eligible for automatic cleanup.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions =
        []
        ++ optional (!mediaCfg.enable) {
          assertion = false;
          message = "mountainous.jellyfin requires mountainous.features.media.enable = true";
        }
        ++ optional (cfg.port != 8096) {
          assertion = false;
          message = "mountainous.jellyfin currently supports only port 8096";
        }
        ++ optional cfg.proxy.enable {
          assertion = tsnetProxyEnabled;
          message = "mountainous.jellyfin requires mountainous.features.tsnet-proxy.enable = true when proxy.enable = true";
        }
        ++ optional cfg.bootstrap.enable {
          assertion = cfg.bootstrap.admin.passwordFile != null;
          message = "mountainous.jellyfin requires bootstrap.admin.passwordFile when bootstrap.enable = true";
        }
        ++ optional cfg.watchedCleaner.enable {
          assertion = cfg.bootstrap.enable && cfg.bootstrap.admin.passwordFile != null;
          message = "mountainous.jellyfin.watchedCleaner requires bootstrap.enable = true with a passwordFile for admin credentials";
        };

      # First pass stays intentionally simple:
      # - host-side service, not inside mountainous.features.vpn-ns
      # - no hardware transcoding work yet
      # - tailnet-only exposure handled separately via tsnet-proxy
      services.jellyfin = {
        enable = true;
        inherit (cfg) group openFirewall user;
      };

      users.users.${cfg.user}.extraGroups = optional (cfg.group != mediaCfg.group) mediaCfg.group;

      systemd.services.jellyfin.serviceConfig.BindReadOnlyPaths = mkAfter [
        cfg.moviesLibraryDir
        cfg.tvLibraryDir
      ];

      systemd.services.jellyfin-seed-bootstrap = mkIf cfg.bootstrap.enable {
        description = "Seed declarative Jellyfin bootstrap state";
        after = ["jellyfin.service"];
        requires = ["jellyfin.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          LoadCredential = bootstrapCredentialEntries;
        };
        script = ''
          ${pkgs.python3}/bin/python <<'PY'
          import json
          import os
          import time
          import urllib.error
          import urllib.parse
          import urllib.request
          import xml.etree.ElementTree as ET
          from pathlib import Path

          base_url = "http://127.0.0.1:${toString cfg.port}"
          auth_header = 'MediaBrowser Client="mountainous-jellyfin-bootstrap", Device="mountainous-jellyfin-bootstrap", DeviceId="mountainous-jellyfin-bootstrap", Version="1.0.0"'
          system_config_file = Path(${builtins.toJSON systemConfigFile})
          network_config_file = Path(${builtins.toJSON networkConfigFile})
          desired_server_name = ${builtins.toJSON cfg.bootstrap.serverName}
          desired_username = ${builtins.toJSON cfg.bootstrap.admin.username}
          desired_remote_access = ${if cfg.bootstrap.remoteAccess then "True" else "False"}
          desired_libraries = [
              {
                  "name": ${builtins.toJSON cfg.bootstrap.libraries.tv.name},
                  "path": ${builtins.toJSON cfg.bootstrap.libraries.tv.path},
                  "collectionType": "tvshows",
              },
              {
                  "name": ${builtins.toJSON cfg.bootstrap.libraries.movies.name},
                  "path": ${builtins.toJSON cfg.bootstrap.libraries.movies.path},
                  "collectionType": "movies",
              },
          ]

          credentials_dir = Path(os.environ["CREDENTIALS_DIRECTORY"])
          password = (credentials_dir / "bootstrap-password").read_text().strip()
          if "=" in password:
              password = password.split("=", 1)[1].strip()

          def read_xml_value(path: Path, tag: str):
              if not path.exists():
                  return None
              try:
                  root = ET.fromstring(path.read_text())
              except ET.ParseError:
                  return None
              node = root.find(tag)
              if node is None:
                  return None
              return node.text or ""

          def read_xml_bool(path: Path, tag: str):
              value = read_xml_value(path, tag)
              if value is None:
                  return None
              return value.strip().lower() == "true"

          def api_request(path, *, method="GET", data=None, token=None, query=None, allow_statuses=()):
              url = f"{base_url}{path}"
              if query:
                  url = f"{url}?{urllib.parse.urlencode(query, doseq=True)}"

              headers = {
                  "Accept": "application/json",
                  "Authorization": auth_header,
              }
              body = None
              if data is not None:
                  body = json.dumps(data).encode()
                  headers["Content-Type"] = "application/json"
              if token is not None:
                  headers["X-Emby-Token"] = token

              request = urllib.request.Request(url, data=body, headers=headers, method=method)

              try:
                  with urllib.request.urlopen(request, timeout=30) as response:
                      raw = response.read()
                      return None if not raw else json.loads(raw)
              except urllib.error.HTTPError as error:
                  if error.code in allow_statuses:
                      return None
                  body_text = error.read().decode()
                  raise RuntimeError(f"Jellyfin API {method} {path} failed: {error.code} {body_text}") from error

          def try_authenticate(username: str, user_password: str):
              url = f"{base_url}/Users/AuthenticateByName"
              headers = {
                  "Accept": "application/json",
                  "Authorization": auth_header,
                  "Content-Type": "application/json",
              }
              request = urllib.request.Request(
                  url,
                  data=json.dumps({"Username": username, "Pw": user_password}).encode(),
                  headers=headers,
                  method="POST",
              )
              try:
                  with urllib.request.urlopen(request, timeout=30) as response:
                      return json.loads(response.read())
              except urllib.error.HTTPError as error:
                  if error.code in (401, 403):
                      return None
                  body_text = error.read().decode()
                  raise RuntimeError(f"Jellyfin authentication failed unexpectedly: {error.code} {body_text}") from error

          def wait_for_public_info():
              for _ in range(60):
                  try:
                      info = api_request("/System/Info/Public")
                      if info is not None:
                          return info
                  except Exception:
                      time.sleep(1)
                      continue
                  time.sleep(1)
              raise RuntimeError("Timed out waiting for Jellyfin API")

          def wait_for_startup_configuration(token=None):
              for _ in range(60):
                  try:
                      configuration = api_request("/Startup/Configuration", token=token)
                      if configuration is not None:
                          return configuration
                  except Exception:
                      time.sleep(1)
                      continue
                  time.sleep(1)
              raise RuntimeError("Timed out waiting for Jellyfin startup configuration")

          def library_matches(folder, desired_library):
              locations = folder.get("Locations") or []
              return (
                  folder.get("Name") == desired_library["name"]
                  and folder.get("CollectionType") == desired_library["collectionType"]
                  and desired_library["path"] in locations
              )

          def get_library(existing_folders, desired_library):
              return next(
                  (folder for folder in existing_folders if library_matches(folder, desired_library)),
                  None,
              )

          def get_total_record_count(result):
              if result is None:
                  return 0
              total = result.get("TotalRecordCount")
              if total is not None:
                  return total
              return len(result.get("Items") or [])

          def tv_library_has_media(path_str: str) -> bool:
              video_extensions = {
                  ".3gp",
                  ".asf",
                  ".avi",
                  ".divx",
                  ".flv",
                  ".m2ts",
                  ".m4v",
                  ".mkv",
                  ".mov",
                  ".mp4",
                  ".mpeg",
                  ".mpg",
                  ".mts",
                  ".ts",
                  ".webm",
                  ".wmv",
              }
              root = Path(path_str)
              if not root.exists():
                  return False
              for candidate in root.rglob("*"):
                  if candidate.is_file() and candidate.suffix.lower() in video_extensions:
                      return True
              return False

          def tv_hierarchy_incomplete(token: str, user_id: str, tv_library):
              if tv_library is None:
                  return False

              locations = tv_library.get("Locations") or []
              if not any(tv_library_has_media(location) for location in locations):
                  return False

              tv_library_item_id = tv_library.get("itemId") or tv_library.get("ItemId")
              if not tv_library_item_id:
                  return True

              try:
                  series_result = api_request(
                      "/Items",
                      token=token,
                      query={
                          "userId": user_id,
                          "parentId": tv_library_item_id,
                          "includeItemTypes": "Series",
                          "recursive": "true",
                          "limit": "1",
                          "enableTotalRecordCount": "true",
                      },
                  )
                  if get_total_record_count(series_result) < 1:
                      return True

                  series_items = series_result.get("Items") or []
                  series_id = series_items[0].get("Id") if series_items else None
                  if not series_id:
                      return True

                  seasons_result = api_request(
                      f"/Shows/{series_id}/Seasons",
                      token=token,
                      query={"userId": user_id},
                  )
                  if get_total_record_count(seasons_result) < 1:
                      return True

                  episodes_result = api_request(
                      f"/Shows/{series_id}/Episodes",
                      token=token,
                      query={
                          "userId": user_id,
                          "limit": "1",
                          "enableTotalRecordCount": "true",
                      },
                  )
                  if get_total_record_count(episodes_result) < 1:
                      return True

                  api_request(
                      "/Shows/NextUp",
                      token=token,
                      query={
                          "userId": user_id,
                          "parentId": tv_library_item_id,
                          "limit": "1",
                          "enableTotalRecordCount": "true",
                      },
                  )
              except RuntimeError:
                  return True

              return False

          public_info = wait_for_public_info()
          startup_completed = bool(public_info.get("StartupWizardCompleted"))
          current_server_name = public_info.get("ServerName") or ""
          current_remote_access = read_xml_bool(network_config_file, "EnableRemoteAccess")
          changes = []

          admin_auth = None
          admin_token = None
          admin_user_id = None
          startup_token = None
          existing_libraries = None

          if startup_completed:
              admin_auth = try_authenticate(desired_username, password)
              if admin_auth is None:
                  raise RuntimeError(
                      "Jellyfin startup is already complete, but the configured bootstrap admin credentials could not authenticate"
                  )
              admin_token = admin_auth["AccessToken"]
              admin_user_id = admin_auth.get("User", {}).get("Id")
              startup_token = admin_token
              existing_libraries = api_request("/Library/VirtualFolders", token=admin_token) or []

              libraries_match = all(
                  any(library_matches(folder, desired_library) for folder in existing_libraries)
                  for desired_library in desired_libraries
              )
              tv_library = get_library(existing_libraries, desired_libraries[0])
              tv_hierarchy_ready = (
                  admin_user_id is not None
                  and not tv_hierarchy_incomplete(admin_token, admin_user_id, tv_library)
              )

              if (
                  current_server_name == desired_server_name
                  and current_remote_access == desired_remote_access
                  and libraries_match
                  and tv_hierarchy_ready
              ):
                  raise SystemExit(0)

          startup_configuration = wait_for_startup_configuration(token=startup_token)
          desired_startup_configuration = dict(startup_configuration or {})
          desired_startup_configuration["ServerName"] = desired_server_name

          if current_server_name != desired_server_name:
              api_request(
                  "/Startup/Configuration",
                  method="POST",
                  data=desired_startup_configuration,
                  token=startup_token,
              )
              changes.append(f"set server name to {desired_server_name}")

          if not startup_completed:
              startup_user = api_request("/Startup/User") or {}
              auth_matches = try_authenticate(desired_username, password) is not None
              if startup_user.get("Name") != desired_username or not auth_matches:
                  api_request(
                      "/Startup/User",
                      method="POST",
                      data={"Name": desired_username, "Password": password},
                  )
                  changes.append(f"configured startup admin {desired_username}")

          if current_remote_access is None or current_remote_access != desired_remote_access:
              api_request(
                  "/Startup/RemoteAccess",
                  method="POST",
                  data={"EnableRemoteAccess": desired_remote_access},
                  token=startup_token,
              )
              changes.append(
                  "enabled remote access" if desired_remote_access else "disabled remote access"
              )

          if admin_auth is None:
              admin_auth = try_authenticate(desired_username, password)
              if admin_auth is None:
                  raise RuntimeError("Failed to authenticate Jellyfin bootstrap admin after applying startup settings")
              admin_token = admin_auth["AccessToken"]
              admin_user_id = admin_auth.get("User", {}).get("Id")

          if existing_libraries is None:
              existing_libraries = api_request("/Library/VirtualFolders", token=admin_token) or []

          for desired_library in desired_libraries:
              if any(library_matches(folder, desired_library) for folder in existing_libraries):
                  continue

              same_name = next(
                  (folder for folder in existing_libraries if folder.get("Name") == desired_library["name"]),
                  None,
              )
              if same_name is not None:
                  if same_name.get("CollectionType") != desired_library["collectionType"]:
                      raise RuntimeError(
                          f"Existing Jellyfin library {desired_library['name']} has collection type {same_name.get('CollectionType')} instead of {desired_library['collectionType']}"
                      )
                  if desired_library["path"] not in (same_name.get("Locations") or []):
                      api_request(
                          "/Library/VirtualFolders/Paths",
                          method="POST",
                          data={"Name": desired_library["name"], "Path": desired_library["path"]},
                          token=admin_token,
                          query={"refreshLibrary": "false"},
                      )
                      changes.append(
                          f"added {desired_library['path']} to Jellyfin library {desired_library['name']}"
                      )
                      existing_libraries = api_request("/Library/VirtualFolders", token=admin_token) or []
                  continue

              same_path = next(
                  (
                      folder
                      for folder in existing_libraries
                      if desired_library["path"] in (folder.get("Locations") or [])
                  ),
                  None,
              )
              if same_path is not None:
                  raise RuntimeError(
                      f"Jellyfin library path {desired_library['path']} is already attached to {same_path.get('Name')}, refusing to create a duplicate bootstrap library"
                  )

              api_request(
                  "/Library/VirtualFolders",
                  method="POST",
                  token=admin_token,
                  query={
                      "name": desired_library["name"],
                      "collectionType": desired_library["collectionType"],
                      "paths": [desired_library["path"]],
                      "refreshLibrary": "false",
                  },
              )
              changes.append(f"created Jellyfin library {desired_library['name']}")
              existing_libraries = api_request("/Library/VirtualFolders", token=admin_token) or []

          current_startup_completed = read_xml_bool(system_config_file, "IsStartupWizardCompleted")
          if current_startup_completed is None:
              current_startup_completed = startup_completed

          if not current_startup_completed:
              api_request("/Startup/Complete", method="POST", token=admin_token)
              changes.append("completed Jellyfin startup wizard")

          if admin_user_id is None:
              raise RuntimeError("Jellyfin bootstrap authentication response did not include a user id")

          tv_library = get_library(existing_libraries, desired_libraries[0])
          if tv_hierarchy_incomplete(admin_token, admin_user_id, tv_library):
              tv_library_item_id = tv_library.get("itemId") or tv_library.get("ItemId")
              api_request(
                  f"/Items/{tv_library_item_id}/Refresh",
                  method="POST",
                  token=admin_token,
              )
              changes.append(
                  f"queued Jellyfin refresh for TV library {tv_library.get('Name') or desired_libraries[0]['name']}"
              )

              for _ in range(60):
                  time.sleep(2)
                  existing_libraries = api_request("/Library/VirtualFolders", token=admin_token) or []
                  tv_library = get_library(existing_libraries, desired_libraries[0])
                  if not tv_hierarchy_incomplete(admin_token, admin_user_id, tv_library):
                      break
              else:
                  raise RuntimeError("Jellyfin TV library hierarchy remained incomplete after a targeted refresh")

          if not changes:
              raise SystemExit(0)
          PY
        '';
      };
    }

    (mkIf cfg.proxy.enable {
      mountainous.features.tsnet-proxy.services.jellyfin = {
        host = "127.0.0.1";
        hostname = cfg.proxy.hostname;
        openFirewall = cfg.proxy.openFirewall;
        port = cfg.port;
        protocol = cfg.proxy.protocol;
      };
    })

    (mkIf cfg.watchedCleaner.enable {
      systemd.timers.jellyfin-watched-cleaner = {
        description = "Timer for cleaning watched Jellyfin media";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = cfg.watchedCleaner.interval;
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };

      systemd.services.jellyfin-watched-cleaner = {
        description = "Delete Jellyfin media watched for over ${toString cfg.watchedCleaner.maxAgeDays} days";
        after = ["jellyfin.service"];
        requires = ["jellyfin.service"];
        serviceConfig = {
          Type = "oneshot";
          LoadCredential = bootstrapCredentialEntries;
        };
        script = ''
          ${pkgs.python3}/bin/python <<'PY'
          import json
          import os
          import sys
          import time
          import urllib.error
          import urllib.parse
          import urllib.request
          from datetime import datetime, timezone, timedelta
          from pathlib import Path

          base_url = "http://127.0.0.1:${toString cfg.port}"
          max_age_days = ${toString cfg.watchedCleaner.maxAgeDays}
          media_types = ${builtins.toJSON cfg.watchedCleaner.mediaTypes}
          admin_username = ${builtins.toJSON cfg.bootstrap.admin.username}
          auth_header = 'MediaBrowser Client="mountainous-jellyfin-watched-cleaner", Device="mountainous-jellyfin-watched-cleaner", DeviceId="mountainous-jellyfin-watched-cleaner", Version="1.0.0"'

          credentials_dir = Path(os.environ["CREDENTIALS_DIRECTORY"])
          password = (credentials_dir / "bootstrap-password").read_text().strip()
          if "=" in password:
              password = password.split("=", 1)[1].strip()

          def api_request(path, *, method="GET", data=None, token=None, query=None):
              url = f"{base_url}{path}"
              if query:
                  url = f"{url}?{urllib.parse.urlencode(query, doseq=True)}"
              headers = {
                  "Accept": "application/json",
                  "Authorization": auth_header,
              }
              body = None
              if data is not None:
                  body = json.dumps(data).encode()
                  headers["Content-Type"] = "application/json"
              if token is not None:
                  headers["X-Emby-Token"] = token
              request = urllib.request.Request(url, data=body, headers=headers, method=method)
              try:
                  with urllib.request.urlopen(request, timeout=30) as response:
                      raw = response.read()
                      return None if not raw else json.loads(raw)
              except urllib.error.HTTPError as error:
                  body_text = error.read().decode()
                  raise RuntimeError(f"Jellyfin API {method} {path}: {error.code} {body_text}") from error

          # Wait for Jellyfin API
          for _ in range(60):
              try:
                  api_request("/System/Info/Public")
                  break
              except Exception:
                  time.sleep(1)
          else:
              raise RuntimeError("Timed out waiting for Jellyfin API")

          # Authenticate as admin
          auth_result = api_request(
              "/Users/AuthenticateByName",
              method="POST",
              data={"Username": admin_username, "Pw": password},
          )
          token = auth_result["AccessToken"]
          user_id = auth_result["User"]["Id"]

          cutoff = datetime.now(timezone.utc) - timedelta(days=max_age_days)

          # Query watched items for the admin user
          result = api_request(
              f"/Users/{user_id}/Items",
              token=token,
              query={
                  "IsPlayed": "true",
                  "Recursive": "true",
                  "IncludeItemTypes": ",".join(media_types),
                  "Fields": "Path",
                  "EnableTotalRecordCount": "true",
                  "Limit": "10000",
              },
          )

          items = (result or {}).get("Items", [])
          deleted = 0
          skipped = 0

          for item in items:
              item_id = item.get("Id")
              item_name = item.get("Name", "Unknown")
              item_type = item.get("Type", "Unknown")
              series_name = item.get("SeriesName", "")
              season_name = item.get("SeasonName", "")
              item_path = item.get("Path", "")
              user_data = item.get("UserData", {})
              last_played = user_data.get("LastPlayedDate")

              if not last_played:
                  continue

              try:
                  last_played_dt = datetime.fromisoformat(last_played.replace("Z", "+00:00"))
              except ValueError:
                  print(f"Skipping {item_name}: could not parse date {last_played}", file=sys.stderr)
                  skipped += 1
                  continue

              if last_played_dt >= cutoff:
                  continue

              label = item_name
              if series_name:
                  parts = [series_name]
                  if season_name:
                      parts.append(season_name)
                  parts.append(item_name)
                  label = " - ".join(parts)

              age_days = (datetime.now(timezone.utc) - last_played_dt).days
              print(f"Deleting {item_type}: {label} (watched {age_days}d ago, path: {item_path})")

              try:
                  api_request(f"/Items/{item_id}", method="DELETE", token=token)
                  deleted += 1
              except RuntimeError as e:
                  print(f"  Failed: {e}", file=sys.stderr)
                  skipped += 1

          print(f"Done: {deleted} deleted, {skipped} skipped, {len(items)} total watched items checked")
          PY
        '';
      };
    })
  ]);
}
