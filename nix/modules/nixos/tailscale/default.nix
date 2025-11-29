{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.tailscale;
  agenixEnabled = config.mountainous.agenix.enable or false;
  secretsDir = ../../../../secrets/agenix;
in {
  options.mountainous.tailscale = {
    enable = mkEnableOption "Tailscale VPN mesh networking";

    extraUpFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["--ssh" "--advertise-exit-node"];
      description = "Extra flags to pass to tailscale up";
    };
  };

  config = mkIf cfg.enable {
    age.secrets.tailscale-ephemeral = mkIf agenixEnabled {
      file = secretsDir + "/tailscale-ephemeral.age";
      mode = "400";
      owner = "root";
      group = "root";
    };

    services.tailscale = {
      enable = true;
      authKeyFile = mkIf agenixEnabled config.age.secrets.tailscale-ephemeral.path;
      authKeyParameters = mkIf agenixEnabled {
        ephemeral = true;
        preauthorized = true;
      };
      extraUpFlags = cfg.extraUpFlags;
    };
  };
}
