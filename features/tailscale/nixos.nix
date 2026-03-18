{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault mkIf;
  cfg = config.mountainous.features.tailscale;
in {
  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      authKeyFile = mkIf (cfg.authKeyFile != null) cfg.authKeyFile;
      extraUpFlags = cfg.extraUpFlags;
      extraSetFlags = cfg.extraSetFlags;
      extraDaemonFlags = cfg.extraDaemonFlags;
    };

    # Always restart to handle deferred boot scenarios.
    systemd.services.tailscaled.serviceConfig.Restart = lib.mkForce "always";

    # Wi-Fi + DHCP can come up well after tailscaled starts, especially on laptops.
    # Give the autoconnect helper enough time to observe the daemon reach Running
    # instead of failing spuriously while tailscaled continues connecting from its
    # persisted state in the background.
    systemd.services.tailscaled-autoconnect.serviceConfig.TimeoutStartSec = mkDefault "10min";
  };
}
