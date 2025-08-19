{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mountainous.hybrid-sleep;
in {
  options.mountainous.hybrid-sleep = {
    enable = lib.mkEnableOption "Whether to enable hybrid sleep";

    delay = lib.mkOption {
      type = lib.types.int;
      default = 15;
      description = "Delay in minutes for idle action and hibernate delay";
    };

    hibernate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to hibernate or only suspend";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.sleep.extraConfig = lib.mkIf cfg.hibernate ''
      HibernateDelaySec=${toString (cfg.delay * 60)}
    '';

    services.logind = {
      lidSwitch =
        if cfg.hibernate
        then "suspend-then-hibernate"
        else "suspend";
      lidSwitchExternalPower = "suspend";
      
      # Use proper NixOS options instead of extraConfig
      powerKey = "hibernate";
      suspendKey =
        if cfg.hibernate
        then "suspend-then-hibernate"
        else "suspend";
      hibernateKey =
        if cfg.hibernate
        then "suspend-then-hibernate"
        else "suspend";
      
      extraConfig = ''
        IdleAction=${
          if cfg.hibernate
          then "hibernate"
          else "suspend"
        }
        IdleActionSec=${toString cfg.delay}min
      '';
    };
  };
}
