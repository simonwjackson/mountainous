{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.features.omi;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.omi = {
    enable = mkEnableOption "Omi wearable transcript pipeline";

    schedule = mkOption {
      type = types.str;
      default = "*:0/15:00";
      description = "Systemd OnCalendar expression for the timer";
    };

    omiDir = mkOption {
      type = types.str;
      default = "/home/simonwjackson/omi";
      description = "Working directory for Omi data";
    };

    user = mkOption {
      type = types.str;
      default = "simonwjackson";
      description = "User to run the service as";
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = "Group to run the service as";
    };
  };
}
