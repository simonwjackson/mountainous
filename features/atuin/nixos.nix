{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault mkIf;
  cfg = config.mountainous.features.atuin;
  atuinKeyFile = ../../secrets/user/simonwjackson/atuin/key.age;
  atuinSessionFile = ../../secrets/user/simonwjackson/atuin/session.age;
  hasKeySecret = builtins.pathExists atuinKeyFile;
  hasSessionSecret = builtins.pathExists atuinSessionFile;
in {
  config = mkIf cfg.enable {
    age.secrets.atuin-key = mkIf hasKeySecret {
      file = atuinKeyFile;
      owner = "simonwjackson";
      mode = "0400";
    };

    age.secrets.atuin-session = mkIf hasSessionSecret {
      file = atuinSessionFile;
      owner = "simonwjackson";
      mode = "0400";
    };

    home-manager.users.simonwjackson.programs.atuin = {
      enable = true;
      enableBashIntegration = true;
      daemon.enable = mkDefault true;
      settings = {
        auto_sync = true;
        enter_accept = true;
        filter_mode_shell_up_key_binding = "workspace";
        inline_height = 10;
        search_mode = "fuzzy";
        secrets_filter = false;
        style = "compact";
        sync_address = "https://api.atuin.sh";
        sync_frequency = "5m";
        key_path = mkIf hasKeySecret config.age.secrets.atuin-key.path;
        session_path = mkIf hasSessionSecret config.age.secrets.atuin-session.path;
      };
    };
  };
}
