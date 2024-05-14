{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption;

  cfg = config.mountainous.atuin;
in {
  options.mountainous.atuin = {
    enable = mkEnableOption "Whether to enable atuin";
  };

  config = lib.mkIf cfg.enable {
    age.secrets.atuin_key.file = ../../../secrets/atuin_key.age;
    age.secrets.atuin_session.file = ../../../secrets/atuin_session.age;

    programs.atuin = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      settings = {
        auto_sync = true;
        enter_accept = true;
        filter_mode_shell_up_key_binding = "workspace";
        inline_height = 10;
        key_path = config.age.secrets.atuin_key.path;
        search_mode = "fuzzy";
        secrets_filter = false;
        session_path = config.age.secrets.atuin_session.path;
        style = "compact";
        sync_address = "https://api.atuin.sh";
        sync_frequency = "5m";
      };
    };
  };
}
