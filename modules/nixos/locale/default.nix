{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption;

  cfg = config.mountainous.locale;
in {
  options.mountainous.locale = {
    enable = mkEnableOption "Whether to enable locale";
  };

  config = lib.mkIf cfg.enable {
    services.automatic-timezoned.enable = true;
    services.localtimed.enable = true;
    location.provider = "geoclue2";
    services.geoclue2.enable = true;
    services.geoclue2.enableDemoAgent = lib.mkForce true;

    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };
}
