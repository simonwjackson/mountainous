{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkDefault mkIf;
  cfg = config.mountainous.features.atuin;
  atuinKeyFile = ../../secrets/user/simonwjackson/atuin/key.age;
  atuinSessionFile = ../../secrets/user/simonwjackson/atuin/session.age;
  hasKeySecret = builtins.pathExists atuinKeyFile;
  hasSessionSecret = builtins.pathExists atuinSessionFile;
  atuinDataDir = "/home/simonwjackson/.local/share/atuin";
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

    # Copy agenix secrets to atuin's default data dir so atuin finds them
    # without needing key_path/session_path overrides (which break sync).
    system.activationScripts.atuin-secrets = mkIf (hasKeySecret && hasSessionSecret) {
      text = ''
        install -d -o simonwjackson -g users -m 0700 ${atuinDataDir}
        install -o simonwjackson -g users -m 0600 \
          ${config.age.secrets.atuin-key.path} ${atuinDataDir}/key
        install -o simonwjackson -g users -m 0600 \
          ${config.age.secrets.atuin-session.path} ${atuinDataDir}/session
      '';
      deps = ["agenix"];
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
      };
    };
  };
}
