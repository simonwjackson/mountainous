{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.tailscale;
  sharedAuthKeyFile = ../../../secrets/tailscale-authkey.age;
  hasSharedAuthKeyFile = builtins.pathExists sharedAuthKeyFile;
  hasSharedAuthKeySecret = config.age.secrets ? tailscale-authkey;
  hasEphemeralSecret = config.age.secrets ? tailscale-ephemeral;
in {
  options.mountainous.tailscale = {
    enable = mkEnableOption "Tailscale VPN mesh networking";

    authKeyFile = mkOption {
      type = types.nullOr types.path;
      default =
        if hasSharedAuthKeySecret
        then config.age.secrets.tailscale-authkey.path
        else if hasEphemeralSecret
        then config.age.secrets.tailscale-ephemeral.path
        else null;
      example = "/run/agenix/tailscale-authkey";
      description = "Path to a Tailscale auth key file used for automatic tailscale up.";
    };

    extraUpFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["--ssh" "--advertise-exit-node"];
      description = "Extra flags to pass to tailscale up.";
    };

    extraSetFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["--netfilter-mode=nodivert"];
      description = "Extra flags to pass to tailscale set after the daemon is running.";
    };

    extraDaemonFlags = mkOption {
      type = types.listOf types.str;
      default = ["--encrypt-state=false"];
      example = ["--stateful-filtering=false"];
      description = "Extra flags to pass to tailscaled.";
    };
  };

  config = mkIf cfg.enable {
    age.secrets.tailscale-authkey = mkIf hasSharedAuthKeyFile {
      file = mkDefault sharedAuthKeyFile;
      owner = mkDefault "root";
      group = mkDefault "root";
      mode = mkDefault "0400";
    };

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
