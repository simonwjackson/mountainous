{lib}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  enable = mkEnableOption "Ephemeral root with persistent storage";

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

  # Special cases
  persistNixStore = mkOption {
    type = types.bool;
    default = false;
    description = "Persist entire /nix store (large, but faster rebuilds)";
  };

  persistLogs = mkOption {
    type = types.bool;
    default = false;
    description = "Persist /var/log across reboots";
  };
}
