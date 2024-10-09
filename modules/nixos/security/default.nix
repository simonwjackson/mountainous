{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption;

  cfg = config.mountainous.security;
in {
  options.mountainous.security = {
    enable = mkEnableOption "Whether to enable security";
    user = lib.mkOption {
      type = lib.types.str;
      default = config.mountainous.user.name;
      description = "";
    };
  };

  config = lib.mkIf cfg.enable {
    security = {
      rtkit.enable = true;

      sudo = {
        wheelNeedsPassword = false;
        extraRules = [
          {
            users = ["${cfg.user}"];

            commands = [
              {
                command = "ALL";
                options = ["NOPASSWD" "SETENV"];
              }
            ];
          }
        ];
      };

      # Increase open file limit for sudoers
      pam.loginLimits = [
        {
          domain = "@wheel";
          type = "-";
          item = "memlock";
          value = "unlimited";
        }
        {
          domain = "${cfg.user}";
          type = "soft";
          item = "memlock";
          value = "unlimited";
        }
        {
          domain = "${cfg.user}";
          type = "hard";
          item = "memlock";
          value = "unlimited";
        }
      ];
    };
  };
}
