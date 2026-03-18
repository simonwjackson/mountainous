{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.biometrics-sync = {
    enable = mkEnableOption "biometrics data sync services";

    user = mkOption {
      type = types.str;
      default = "simonwjackson";
      description = "User to run sync services as.";
    };

    oura = {
      enable = mkEnableOption "Oura Ring data sync";

      schedule = mkOption {
        type = types.str;
        default = "*-*-* *:00,30:00";
        description = "Systemd OnCalendar expression for Oura sync.";
      };
    };

    withings = {
      enable = mkEnableOption "Withings scale data sync";

      schedule = mkOption {
        type = types.str;
        default = "*-*-* 16:00:00";
        description = "Systemd OnCalendar expression for Withings sync.";
      };
    };

    ketomojo = {
      enable = mkEnableOption "Keto-Mojo readings sync";

      schedule = mkOption {
        type = types.str;
        default = "*-*-* 10:10:00";
        description = "Systemd OnCalendar expression for Keto-Mojo sync.";
      };
    };
  };
}
