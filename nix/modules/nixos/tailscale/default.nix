{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.tailscale;
  agenixEnabled = config.mountainous.agenix.enable or false;

  # Check if secret exists (auto-discovered by agenix module)
  hasSecret = config.age.secrets ? tailscale-ephemeral;
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
    # Secret is auto-discovered by mountainous.agenix module
    # No declaration needed here - just reference it

    services.tailscale = {
      enable = true;
      authKeyFile = mkIf (agenixEnabled && hasSecret) config.age.secrets.tailscale-ephemeral.path;
      extraUpFlags = cfg.extraUpFlags;
      extraDaemonFlags = ["--encrypt-state=false"];
    };

    # Tailscaled service overrides
    systemd.services.tailscaled =
      {
        # Restart on abnormal exits (signals, timeouts) but not clean exits
        serviceConfig.Restart = lib.mkForce "on-abnormal";
      }
      // lib.optionalAttrs (config.mountainous.impermanence.enable or false) {
        # Ensure tailscaled waits for persistent storage bind mount
        after = ["local-fs.target"];
        requires = ["local-fs.target"];
      };

    # Impermanence integration - persist Tailscale state
    environment.persistence."${config.mountainous.impermanence.persistPath}" = mkIf (config.mountainous.impermanence.enable or false) {
      directories = ["/var/lib/tailscale"];
    };
  };
}
