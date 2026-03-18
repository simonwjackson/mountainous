{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mountainous.features.syncthing;
  secretsCfg = config.mountainous.features.secrets;
  home = config.user.home;
  hostname = secretsCfg.hostname;

  syncthingHome = "${home}/.config/syncthing";
  certSource = "${secretsCfg.secretsDir}/syncthing-cert";
  keySource = "${secretsCfg.secretsDir}/syncthing-key";

  syncLib = import ./lib.nix {inherit lib;};
  syncConfig = syncLib.mkSyncConfig {
    hostsRoot = ../../hosts;
    devicesRoot = ../../devices;
    inherit hostname;
    shares = cfg.shares;
  };

  localDeviceId = syncConfig.allDeviceIds.${hostname};

  # ── REST API init script ─────────────────────────────────────────────
  # Modelled after the NixOS syncthing-init service: wait for the daemon,
  # then PUT devices and folders via the REST API.

  devicePuts = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: entry: ''
    put "/rest/config/devices/${entry.id}" '${builtins.toJSON {
      deviceID = entry.id;
      name = name;
      addresses = entry.addresses;
      compression = "metadata";
      introducer = false;
      paused = false;
    }}'
  '') syncConfig.deviceEntries);

  folderPuts = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: folder: let
    deviceList =
      [
        {
          deviceID = localDeviceId;
          introducedBy = "";
          encryptionPassword = "";
        }
      ]
      ++ map (devName: {
        deviceID = syncConfig.allDeviceIds.${devName};
        introducedBy = "";
        encryptionPassword = "";
      })
      folder.devices;
  in ''
    put "/rest/config/folders/${name}" '${builtins.toJSON {
      id = name;
      label = name;
      path = folder.path;
      type = folder.type;
      devices = deviceList;
      rescanIntervalS = folder.rescanIntervalS;
      ignorePerms = folder.ignorePerms;
      autoNormalize = true;
      fsWatcherEnabled = true;
    }}'
  '') syncConfig.syncthingFolders);

  expectedDeviceIds = lib.mapAttrsToList (_: e: e.id) syncConfig.deviceEntries;
  expectedFolderIds = lib.attrNames syncConfig.syncthingFolders;

  # Build case-match arms for cleanup. Self + configured peers are kept.
  deviceKeepPattern = lib.concatStringsSep "|" ([localDeviceId] ++ expectedDeviceIds);
  folderKeepPattern = lib.concatStringsSep "|" expectedFolderIds;

  initScript = pkgs.writeShellScript "syncthing-init" ''
    set -euo pipefail

    CURL="${pkgs.curl}/bin/curl"
    SED="${pkgs.gnused}/bin/sed"
    JQ="${pkgs.jq}/bin/jq"
    CONFIG_FILE="${syncthingHome}/config.xml"
    API_URL="http://127.0.0.1:8384"

    # Wait for config.xml (created on first daemon start)
    for _ in $(seq 1 120); do
      [ -f "$CONFIG_FILE" ] && break
      sleep 1
    done
    if [ ! -f "$CONFIG_FILE" ]; then
      echo "syncthing-init: config.xml not found after 120s" >&2
      exit 1
    fi

    API_KEY=$($SED -n 's/.*<apikey>\(.*\)<\/apikey>.*/\1/p' "$CONFIG_FILE" | head -1)
    if [ -z "$API_KEY" ]; then
      echo "syncthing-init: could not extract API key" >&2
      exit 1
    fi

    # Wait for REST API
    for _ in $(seq 1 120); do
      $CURL -sf -o /dev/null -H "X-API-Key: $API_KEY" "$API_URL/rest/system/status" && break
      sleep 1
    done

    put() {
      local endpoint="$1" payload="$2"
      $CURL -sf -X PUT \
        -H "X-API-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$API_URL$endpoint" >/dev/null
    }

    # ── Apply devices ──────────────────────────────────────────────────
    ${devicePuts}

    # ── Apply folders ──────────────────────────────────────────────────
    ${folderPuts}

    # ── Override: remove unmanaged devices ──────────────────────────────
    ${lib.optionalString (expectedDeviceIds != []) ''
      CURRENT_DEVICES=$($CURL -sf -H "X-API-Key: $API_KEY" "$API_URL/rest/config/devices" | $JQ -r '.[].deviceID')
      for dev_id in $CURRENT_DEVICES; do
        case "$dev_id" in
          ${deviceKeepPattern}) ;;
          *) $CURL -sf -X DELETE -H "X-API-Key: $API_KEY" "$API_URL/rest/config/devices/$dev_id" >/dev/null || true ;;
        esac
      done
    ''}

    # ── Override: remove unmanaged folders ──────────────────────────────
    ${lib.optionalString (expectedFolderIds != []) ''
      CURRENT_FOLDERS=$($CURL -sf -H "X-API-Key: $API_KEY" "$API_URL/rest/config/folders" | $JQ -r '.[].id')
      for folder_id in $CURRENT_FOLDERS; do
        case "$folder_id" in
          ${folderKeepPattern}) ;;
          *) $CURL -sf -X DELETE -H "X-API-Key: $API_KEY" "$API_URL/rest/config/folders/$folder_id" >/dev/null || true ;;
        esac
      done
    ''}

    echo "syncthing-init: configuration applied"
  '';

  # Wrapper: fork the init script, then exec syncthing so session-services
  # tracks the real syncthing PID (not a shell wrapper).
  wrapperScript = pkgs.writeShellScript "syncthing-start" ''
    (sleep 2; ${initScript}) &
    exec ${pkgs.syncthing}/bin/syncthing serve --no-browser --home="${syncthingHome}"
  '';
in {
  config = lib.mkIf cfg.enable {
    environment.packages = [pkgs.syncthing pkgs.curl pkgs.jq];

    mountainous.features.session-services.syncthing = {
      enable = true;
      command = "${wrapperScript}";
      startup = "ensure-running";
    };

    build.activationAfter.syncthingIdentity = ''
      mkdir -p "${syncthingHome}"

      if [[ -f "${certSource}" ]] && [[ -f "${keySource}" ]]; then
        $VERBOSE_ECHO "Installing syncthing identity to ${syncthingHome}"
        cp -f "${certSource}" "${syncthingHome}/cert.pem"
        cp -f "${keySource}" "${syncthingHome}/key.pem"
        chmod 600 "${syncthingHome}/key.pem"
        chmod 644 "${syncthingHome}/cert.pem"
      else
        $VERBOSE_ECHO "Syncthing identity secrets not found; skipping"
      fi
    '';
  };
}
