{
  options,
  config,
  pkgs,
  lib,
  ...
}: {
  security = {
    rtkit.enable = true;

    sudo = {
      wheelNeedsPassword = false;
      extraRules = [
        {
          users = ["${config.mountainous.user.name}"];

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
        domain = "${config.mountainous.user.name}";
        type = "soft";
        item = "memlock";
        value = "unlimited";
      }
      {
        domain = "${config.mountainous.user.name}";
        type = "hard";
        item = "memlock";
        value = "unlimited";
      }
    ];
  };
}
