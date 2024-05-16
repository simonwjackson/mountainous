{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption;

  cfg = config.mountainous.bat;
in {
  options.mountainous.bat = {
    enable = mkEnableOption "Whether to enable bat";
  };

  config = lib.mkIf cfg.enable {
    programs.bat = {
      enable = true;

      themes = {
        dracula = builtins.readFile (pkgs.fetchFromGitHub
          {
            owner = "dracula";
            repo = "sublime"; # Bat uses sublime syntax for its themes
            rev = "26c57ec282abcaa76e57e055f38432bd827ac34e";
            sha256 = "019hfl4zbn4vm4154hh3bwk6hm7bdxbr1hdww83nabxwjn99ndhv";
          }
          + "/Dracula.tmTheme");
      };

      config = {
        theme = "Dracula";
        italic-text = "always";
      };
    };
  };
}
