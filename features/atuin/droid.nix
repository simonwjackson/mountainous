{
  config,
  lib,
  ...
}: let
  cfg = config.mountainous.features.atuin;
in {
  config = lib.mkIf cfg.enable {
    home-manager.config.programs.atuin = {
      enable = true;
      enableBashIntegration = true;
      settings = {
        auto_sync = true;
        enter_accept = true;
        filter_mode_shell_up_key_binding = "workspace";
        inline_height = 10;
        key_path = cfg.keyPath;
        search_mode = "fuzzy";
        secrets_filter = false;
        session_path = cfg.sessionPath;
        style = "compact";
        sync_address = "https://api.atuin.sh";
        sync_frequency = "5m";
      };
    };
  };
}
