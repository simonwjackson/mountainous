{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types;
  cfg = config.mountainous.media;
in {
  options.mountainous.media = {
    user = mkOption {
      type = types.str;
      default = "media";
      description = "Default user for media services";
    };

    group = mkOption {
      type = types.str;
      default = "media";
      description = "Default group for media services";
    };

    paths = mkOption {
      type = types.attrsOf types.path;
      default = {};
      description = ''
        Shared media content paths used by multiple services.
        Common keys: movies, series, music.

        These paths are created with ownership from media.user and media.group.
      '';
      example = lib.literalExpression ''
        {
          movies = "/tundra/merged/iceberg/movies";
          series = "/tundra/merged/iceberg/series";
          music = "/tundra/merged/iceberg/music";
        }
      '';
    };
  };

  config = mkIf (cfg.paths != {}) {
    # Create all defined media paths with media user/group ownership
    mountainous.directories.paths =
      lib.mapAttrs (
        name: path: {
          owner = cfg.user;
          group = cfg.group;
          mode = "0755";
          parents = true;
        }
      )
      cfg.paths;

    # Ensure media user and group exist if paths are defined
    users.users.${cfg.user} = lib.mkIf (cfg.user == "media") (lib.mkDefault {
      isSystemUser = true;
      group = cfg.group;
      description = "Media services user";
    });

    users.groups.${cfg.group} = lib.mkIf (cfg.group == "media") (lib.mkDefault {});
  };
}
