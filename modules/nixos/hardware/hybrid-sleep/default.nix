{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mountainous.hardware.hybrid-sleep;
in {
  options.mountainous.hardware.hybrid-sleep = {
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

    services.logind.lidSwitch =
      if cfg.hibernate
      then "suspend-then-hibernate"
      else "suspend";
    services.logind.lidSwitchExternalPower = "suspend";

    services.logind.extraConfig = ''
      HandlePowerKey=${
        if cfg.hibernate
        then "suspend-then-hibernate"
        else "suspend"
      }
      HandleSuspendKey=${
        if cfg.hibernate
        then "suspend-then-hibernate"
        else "suspend"
      }
      HandleHibernateKey=${
        if cfg.hibernate
        then "suspend-then-hibernate"
        else "suspend"
      }
      IdleAction=${
        if cfg.hibernate
        then "hibernate"
        else "suspend"
      }
      IdleActionSec=${toString cfg.delay}min
    '';
  };
}
