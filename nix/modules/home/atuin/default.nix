{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf;

  cfg = config.mountainous.atuin;
in {
  options.mountainous.atuin = {
    enable = mkEnableOption "Whether to enable atuin";

    key_path = mkOption {
      type = lib.types.str;
      description = "Path to atuin key file";
    };

    session_path = mkOption {
      type = lib.types.str;
      description = "Path to atuin session file";
    };
  };

  config = mkIf cfg.enable {
    programs.atuin = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      daemon.enable = true;
      settings = {
        auto_sync = true;
        enter_accept = true;
        filter_mode_shell_up_key_binding = "workspace";
        inline_height = 10;
        key_path = cfg.key_path;
        search_mode = "fuzzy";
        secrets_filter = false;
        session_path = cfg.session_path;
        style = "compact";
        sync_address = "https://api.atuin.sh";
        sync_frequency = "5m";
      };
    };
  };
}
