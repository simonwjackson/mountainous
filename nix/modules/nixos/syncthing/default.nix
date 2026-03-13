{
  config,
  options,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkDefault mkIf types mapAttrs filter attrNames optionalAttrs;

  cfg = config.mountainous.syncthing;
  hostname = config.networking.hostName;

  # ── Device discovery from plain files ────────────────────────────────
  # Each host/device drops a `syncthing-device-id` file in its directory.
  # No cross-evaluation needed — just builtins.readFile on static data.

  hostsRoot = ../../../../hosts;
  devicesRoot = ../../../../devices;

  # Scan a directory for subdirs containing syncthing-device-id files
  discoverDevices = root:
    let
      entries =
        if builtins.pathExists root
        then builtins.readDir root
        else {};
      dirs = attrNames (lib.filterAttrs (_: type: type == "directory") entries);
      hasId = name: builtins.pathExists (root + "/${name}/syncthing-device-id");
      withIds = filter hasId dirs;
    in
      builtins.listToAttrs (map (name: {
        inherit name;
        value = lib.removeSuffix "\n" (builtins.readFile (root + "/${name}/syncthing-device-id"));
      }) withIds);

  # All known devices: hosts + external devices (phones, etc.)
  allDeviceIds = (discoverDevices hostsRoot) // (discoverDevices devicesRoot);

  # Peers = everyone except self
  peerIds = removeAttrs allDeviceIds [hostname];
  peerNames = attrNames peerIds;

  # Build syncthing device entries
  deviceEntries = mapAttrs (_: id: {
    inherit id;
    addresses = ["dynamic"];
  }) peerIds;

  # ── Secrets ──────────────────────────────────────────────────────────
  secretsRoot = ../../../../secrets;
  syncthingCertPath = secretsRoot + "/hosts/${hostname}/syncthing-cert.age";
  syncthingKeyPath = secretsRoot + "/hosts/${hostname}/syncthing-key.age";
  hasSyncthingSecrets = builtins.pathExists syncthingCertPath && builtins.pathExists syncthingKeyPath;

  # ── Folder config ───────────────────────────────────────────────────
  # Every folder is shared with all peers. Syncthing gracefully handles
  # peers that don't have a matching folder (they just ignore/prompt).
  folders = mapAttrs (name: folderCfg:
    {
      path = folderCfg.path;
      devices = peerNames;
      type = folderCfg.type;
      ignorePerms = folderCfg.ignorePerms;
      rescanIntervalS = folderCfg.rescanIntervalS;
    }
    // optionalAttrs (folderCfg.ignorePatterns != null) {
      inherit (folderCfg) ignorePatterns;
    }
    // optionalAttrs (folderCfg.versioning != null) {
      inherit (folderCfg) versioning;
    })
  cfg.folders;

  # ── Submodule types ─────────────────────────────────────────────────
  folderType = types.submodule {
    options = {
      path = mkOption {
        type = types.str;
        description = "Local path for this synced folder";
        example = "/home/simonwjackson/documents";
      };

      type = mkOption {
        type = types.enum ["sendreceive" "sendonly" "receiveonly"];
        default = "sendreceive";
        description = "Folder type";
      };

      ignorePerms = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to ignore permission changes";
      };

      rescanIntervalS = mkOption {
        type = types.int;
        default = 3600;
        description = "Rescan interval in seconds";
      };

      ignorePatterns = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = ''
          Syncthing ignore patterns for this folder.
          Set to [] to explicitly clear existing ignore patterns.
        '';
        example = [
          "**/node_modules"
          "**/.direnv"
          "**/__pycache__"
        ];
      };

      versioning = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            type = mkOption {
              type = types.enum ["simple" "staggered" "trashcan" "external"];
              description = "Versioning type";
            };
            params = mkOption {
              type = types.attrsOf types.str;
              default = {};
              description = "Versioning parameters";
            };
          };
        });
        default = null;
        description = "Optional versioning configuration";
      };
    };
  };
in {
  options.mountainous.syncthing = {
    enable = mkEnableOption "Syncthing file synchronization";

    user = mkOption {
      type = types.str;
      default = "simonwjackson";
      description = "User to run syncthing as";
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = "Group to run syncthing as";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/syncthing";
      description = "Syncthing data directory";
    };

    configDir = mkOption {
      type = types.str;
      default = "/var/lib/syncthing/.config/syncthing";
      description = "Syncthing configuration directory";
    };

    guiAddress = mkOption {
      type = types.str;
      default = "127.0.0.1:8384";
      description = "Address for the web GUI";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports for syncthing";
    };

    folders = mkOption {
      type = types.attrsOf folderType;
      default = {};
      description = "Folders to synchronize (shared with all peers by default)";
      example = {
        notes.path = "/home/simonwjackson/notes";
      };
    };
  };

  config = mkIf cfg.enable {
    # Default folders — hosts can override with mkForce or add more
    mountainous.syncthing.folders = {
      pi-config = {
        path = mkDefault "/home/${cfg.user}/.pi";
        ignorePatterns = mkDefault [
          "**/.git"
          "**/.git/**"
          "**/node_modules"
          "**/node_modules/**"
          "**/.direnv"
          "**/.direnv/**"
          "**/.venv"
          "**/.venv/**"
          "**/venv"
          "**/venv/**"
          "**/__pycache__"
          "**/__pycache__/**"
          "**/.mypy_cache"
          "**/.mypy_cache/**"
          "**/.pytest_cache"
          "**/.pytest_cache/**"
          "**/.ruff_cache"
          "**/.ruff_cache/**"
          "**/.cache"
          "**/.cache/**"
          "**/dist"
          "**/dist/**"
          "**/build"
          "**/build/**"
          "**/result"
          "**/result/**"
          "**/tmp"
          "**/tmp/**"
          "**/.tmp"
          "**/.tmp/**"
          "**/agent/bin"
          "**/agent/bin/**"
          "**/*.log"
        ];
      };

      biometrics.path = mkDefault "/home/${cfg.user}/biometrics";
      fitness.path = mkDefault "/home/${cfg.user}/fitness";
      flakey.path = mkDefault "/home/${cfg.user}/flakey";
      omi.path = mkDefault "/home/${cfg.user}/omi";
      research.path = mkDefault "/home/${cfg.user}/research";
      therapy.path = mkDefault "/home/${cfg.user}/therapy";
      transcripts.path = mkDefault "/home/${cfg.user}/transcripts";
      nutrition.path = mkDefault "/home/${cfg.user}/.local/share/nutrition";
      tasks.path = mkDefault "/home/${cfg.user}/.local/share/tasks";
    };

    services.syncthing = {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      dataDir = cfg.dataDir;
      configDir = cfg.configDir;
      guiAddress = cfg.guiAddress;
      openDefaultPorts = cfg.openFirewall;

      cert = mkIf hasSyncthingSecrets config.age.secrets.syncthing-cert.path;
      key = mkIf hasSyncthingSecrets config.age.secrets.syncthing-key.path;

      overrideDevices = true;
      overrideFolders = true;

      settings = {
        devices = deviceEntries;
        inherit folders;

        options = {
          urAccepted = -1;
          localAnnounceEnabled = true;
          globalAnnounceEnabled = true;
          relaysEnabled = true;
        };
      };
    };

    age.secrets = mkIf hasSyncthingSecrets {
      syncthing-cert = {
        file = syncthingCertPath;
        owner = cfg.user;
        group = cfg.group;
        mode = "400";
      };
      syncthing-key = {
        file = syncthingKeyPath;
        owner = cfg.user;
        group = cfg.group;
        mode = "400";
      };
    };

    boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;

    # The upstream NixOS module applies devices/folders through a oneshot
    # syncthing-init service. Ensure config changes on switch actually rerun it.
    systemd.services.syncthing-init = {
      restartIfChanged = true;
      stopIfChanged = true;
    };
  };
}
