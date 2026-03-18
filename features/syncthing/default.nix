{
  config,
  lib,
  mountainousPlatform ? "nixos",
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.mountainous.features.syncthing;

  shareType = types.submodule {
    options = {
      enable = mkEnableOption "Syncthing share";

      path = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Explicit local path for this share.
          Leave unset to use a default provided elsewhere, such as the core preset.
        '';
        example = "/srv/storage/media";
      };

      type = mkOption {
        type = types.enum [
          "sendreceive"
          "sendonly"
          "receiveonly"
        ];
        default = "sendreceive";
        description = "Folder type";
      };

      ignorePerms = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to ignore permission changes";
      };

      shareWith = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = ''
          Optional explicit device list for this share.
          Include or omit the local host name; it is filtered automatically.
          Defaults to all known peers when unset.
        '';
        example = [
          "fuji"
          "yari"
        ];
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
          Syncthing ignore patterns for this share.
          Set to [] to explicitly clear existing ignore patterns.
        '';
        example = [
          "**/node_modules"
          "**/.direnv"
          "**/__pycache__"
        ];
      };

      versioning = mkOption {
        type = types.nullOr (
          types.submodule {
            options = {
              type = mkOption {
                type = types.enum [
                  "simple"
                  "staggered"
                  "trashcan"
                  "external"
                ];
                description = "Versioning type";
              };
              params = mkOption {
                type = types.attrsOf types.str;
                default = { };
                description = "Versioning parameters";
              };
            };
          }
        );
        default = null;
        description = "Optional versioning configuration";
      };
    };
  };
in {
  imports = lib.optional (mountainousPlatform == "nixos") ./nixos.nix;

  options.mountainous.features.syncthing = {
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

    shares = mkOption {
      type = types.attrsOf shareType;
      default = { };
      description = "Shares to synchronize";
      example = {
        notes = {
          enable = true;
          path = "/home/simonwjackson/notes";
        };
      };
    };
  };

  config = mkIf cfg.enable (lib.optionalAttrs (mountainousPlatform == "nixos") {
    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];
  });
}
