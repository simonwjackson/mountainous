{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.features.kroger;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.kroger = {
    enable = mkEnableOption "Kroger/King Soopers grocery API tools";

    storeId = mkOption {
      type = types.str;
      default = "62000082";
      description = "Kroger location ID (default: King Soopers Golden Road)";
    };

    clientIdFile = mkOption {
      type = types.path;
      description = "Path to file containing Kroger API client ID";
    };

    clientSecretFile = mkOption {
      type = types.path;
      description = "Path to file containing Kroger API client secret";
    };

    user = mkOption {
      type = types.str;
      default = "simonwjackson";
      description = "User to run Kroger services as";
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = "Group to run Kroger services as";
    };

    weeklyDeals = {
      enable = mkEnableOption "weekly keto deals scan";

      schedule = mkOption {
        type = types.str;
        default = "Wed *-*-* 09:00:00";
        description = "Systemd OnCalendar expression for weekly deals scan";
      };
    };
  };
}
