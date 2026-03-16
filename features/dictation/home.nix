{
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  cfg = osConfig.mountainous.features.dictation or {};
  enabled = cfg.enable or false;

  configLines =
    lib.optional ((cfg.apiKeyEnvFile or null) != null) "source ${cfg.apiKeyEnvFile}"
    ++ lib.optional ((cfg.model or "whisper-large-v3-turbo") != "whisper-large-v3-turbo") "DICTATION_MODEL=${cfg.model}"
    ++ lib.optional ((cfg.language or "en") != "en") "DICTATION_LANGUAGE=${cfg.language}";

  configContent = lib.concatStringsSep "\n" configLines;
  hasConfig = configLines != [];
in {
  config = lib.mkIf enabled {
    home.packages = [pkgs.dictation];

    xdg.configFile."dictation/config" = lib.mkIf hasConfig {
      text = configContent;
    };
  };
}
