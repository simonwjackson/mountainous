{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption;

  cfg = config.mountainous.kitty;
in {
  options.mountainous.kitty = {
    enable = mkEnableOption "Whether to enable kitty";
    shellIntegration = {
      enableBashIntegration = true;
      enableZshIntegration = true;
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      sessionVariables = {
        TERMINAL = "kitty";
      };
    };

    programs.kitty = {
      enable = true;
      extraConfig = builtins.readFile ./kitty.conf;
    };
  };
}
