{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types filterAttrs mapAttrs filter attrNames elem optionalAttrs;

  cfg = config.mountainous.syncthing;
  hostname = config.networking.hostName;
  agenixEnabled = config.mountainous.agenix.enable or false;
  secretsDir = ../../../../secrets/agenix;

  # Import the central device ID registry
  allDeviceIds = import ./devices.nix;

  # All NixOS systems from the flake
  allSystems = inputs.self.nixosConfigurations or {};

  # Filter to systems with syncthing enabled AND valid device ID (excluding self)
  syncthingSystems = filterAttrs (name: system:
    name != hostname
    && allDeviceIds ? ${name}
    && (system.config.mountainous.syncthing.enable or false)
  ) allSystems;

  # Build device entries for services.syncthing.settings.devices
  # Only include devices that actually exist in the registry
  nixosDevices = mapAttrs (name: _system: {
    id = allDeviceIds.${name};
    addresses = ["dynamic"];
  }) syncthingSystems;

  # Build extraDevices entries (phones, external servers)
  externalDevices = mapAttrs (name: dev: {
    inherit (dev) id;
    addresses = dev.addresses or ["dynamic"];
  }) cfg.extraDevices;

  # Combine all devices
  allDevices = nixosDevices // externalDevices;

  # For each folder, determine which devices should sync
  resolveDevices = folderName: folderCfg:
    if folderCfg.devices != []
    then
      # Explicit device list - filter to only those with valid IDs
      filter (name: allDevices ? ${name}) folderCfg.devices
    else
      # Auto-discover: NixOS systems that also have this folder
      (filter (name:
        (syncthingSystems.${name}.config.mountainous.syncthing.folders or {}) ? ${folderName}
      ) (attrNames syncthingSystems))
      ++
      # Plus extraDevices that list this folder
      (filter (name:
        elem folderName (cfg.extraDevices.${name}.folders or [])
      ) (attrNames cfg.extraDevices));

  # Build folder config for services.syncthing.settings.folders
  folders = mapAttrs (name: folderCfg: {
    path = folderCfg.path;
    devices = resolveDevices name folderCfg;
    type = folderCfg.type;
    ignorePerms = folderCfg.ignorePerms;
    rescanIntervalS = folderCfg.rescanIntervalS;
  } // optionalAttrs (folderCfg.versioning != null) {
    inherit (folderCfg) versioning;
  }) cfg.folders;

  # Folder submodule type
  folderType = types.submodule {
    options = {
      path = mkOption {
        type = types.str;
        description = "Local path for this synced folder";
        example = "/home/simonwjackson/documents";
      };

      devices = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          List of device names to share this folder with.
          Empty list (default) means share with ALL peers that have this folder.
        '';
        example = ["zao" "aka" "fuji"];
      };

      type = mkOption {
        type = types.enum ["sendreceive" "sendonly" "receiveonly"];
        default = "sendreceive";
        description = "Folder type: sendreceive (default), sendonly, or receiveonly";
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

  # External device submodule type
  extraDeviceType = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        description = "Syncthing device ID";
        example = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
      };

      addresses = mkOption {
        type = types.listOf types.str;
        default = ["dynamic"];
        description = "List of addresses for this device";
      };

      folders = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of folder names to share with this device";
        example = ["notes" "photos"];
      };
    };
  };

in {
  options.mountainous.syncthing = {
    enable = mkEnableOption "Syncthing file synchronization with auto-discovery";

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
      description = "Open firewall ports for syncthing (22000/tcp, 22000/udp, 21027/udp)";
    };

    folders = mkOption {
      type = types.attrsOf folderType;
      default = {};
      description = "Folders to synchronize";
      example = {
        notes = {
          path = "/home/simonwjackson/notes";
        };
        documents = {
          path = "/home/simonwjackson/documents";
          devices = ["zao" "aka"];
        };
      };
    };

    extraDevices = mkOption {
      type = types.attrsOf extraDeviceType;
      default = {};
      description = "Non-NixOS devices (phones, external servers)";
      example = {
        phone = {
          id = "PHONE-ID-HERE";
          folders = ["notes" "photos"];
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # Agenix secrets for syncthing key and cert
    age.secrets = mkIf (agenixEnabled && builtins.pathExists (secretsDir + "/${hostname}-syncthing-key.age")) {
      "${hostname}-syncthing-key" = {
        file = secretsDir + "/${hostname}-syncthing-key.age";
        mode = "400";
        owner = cfg.user;
        group = cfg.group;
      };
      "${hostname}-syncthing-cert" = {
        file = secretsDir + "/${hostname}-syncthing-cert.age";
        mode = "400";
        owner = cfg.user;
        group = cfg.group;
      };
    };

    # Configure syncthing service
    services.syncthing = {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      dataDir = cfg.dataDir;
      configDir = cfg.configDir;
      guiAddress = cfg.guiAddress;
      openDefaultPorts = cfg.openFirewall;

      # Use agenix-managed key and cert if available
      key = mkIf (agenixEnabled && builtins.pathExists (secretsDir + "/${hostname}-syncthing-key.age"))
        config.age.secrets."${hostname}-syncthing-key".path;
      cert = mkIf (agenixEnabled && builtins.pathExists (secretsDir + "/${hostname}-syncthing-cert.age"))
        config.age.secrets."${hostname}-syncthing-cert".path;

      overrideDevices = true;
      overrideFolders = true;

      settings = {
        devices = allDevices;
        folders = folders;

        options = {
          urAccepted = -1; # Disable usage reporting
          localAnnounceEnabled = true;
          globalAnnounceEnabled = true;
          relaysEnabled = true;
        };
      };
    };

    # Increase inotify watches for large folder sets
    boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;

    # Impermanence integration - persist syncthing data
    environment.persistence."${config.mountainous.impermanence.persistPath}" = mkIf (config.mountainous.impermanence.enable or false) {
      directories = [
        {
          directory = cfg.dataDir;
          user = cfg.user;
          group = cfg.group;
          mode = "0700";
        }
      ];
    };
  };
}
