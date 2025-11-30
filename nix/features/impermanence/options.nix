{lib}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  enable = mkEnableOption "Ephemeral root with persistent storage";

  # Disko integration
  disko = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Auto-generate disko subvolumes for impermanence";
    };

    diskName = mkOption {
      type = types.str;
      default = "main";
      description = "Name of the disk in disko.devices.disk to add subvolumes to";
    };

    partitionName = mkOption {
      type = types.str;
      default = "root";
      description = "Name of the partition to add subvolumes to";
    };

    mountOptions = mkOption {
      type = types.listOf types.str;
      default = [
        "compress=zstd"
        "noatime"
        "nodiratime"
        "discard=async"
        "space_cache=v2"
      ];
      description = "Default btrfs mount options for impermanence subvolumes";
    };
  };

  # Storage configuration
  persistPath = mkOption {
    type = types.str;
    default = "/tundra/permafrost";
    description = "Path to persistent storage mount";
  };

  persistDevice = mkOption {
    type = types.nullOr types.str;
    default = null;
    description = "Device to mount at persistPath (e.g., /dev/mapper/vg-persist)";
  };

  persistFsType = mkOption {
    type = types.str;
    default = "btrfs";
    description = "Filesystem type for persistent storage";
  };

  persistOptions = mkOption {
    type = types.listOf types.str;
    default = ["defaults"];
    description = "Mount options for persistent storage";
  };

  # Root filesystem
  rootSize = mkOption {
    type = types.str;
    default = "2G";
    description = "Size of tmpfs root filesystem";
  };

  # User configuration
  user = mkOption {
    type = types.str;
    default = "simonwjackson";
    description = "Primary user whose home is persisted";
  };

  # Auto-detection controls
  autoDetect = {
    fromDevice = mkOption {
      type = types.bool;
      default = true;
      description = "Auto-add persistence based on device.role/capabilities";
    };

    fromFeatures = mkOption {
      type = types.bool;
      default = true;
      description = "Let enabled features add their own persistence";
    };
  };

  # Manual additions
  extraDirectories = mkOption {
    type = types.listOf (types.either types.str (types.attrsOf types.anything));
    default = [];
    description = "Additional directories to persist";
  };

  extraFiles = mkOption {
    type = types.listOf types.str;
    default = [];
    description = "Additional files to persist";
  };

  # Subvolume controls
  persistNixStore = mkOption {
    type = types.bool;
    default = true;
    description = "Create @nix subvolume for /nix store";
  };

  persistLogs = mkOption {
    type = types.bool;
    default = false;
    description = "Persist /var/log across reboots";
  };
}
