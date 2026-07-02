{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.features.tailscale;
  sharedAuthKeyFile = ../../secrets/tailscale-authkey.age;
  hasSharedAuthKeyFile = builtins.pathExists sharedAuthKeyFile;
  hasSharedAuthKeySecret = config.age.secrets ? tailscale-authkey;
  hasEphemeralSecret = config.age.secrets ? tailscale-ephemeral;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.tailscale = {
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

    acceptDns = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether personal machines should accept Tailscale DNS configuration.
        Keep this enabled so short MagicDNS names resolve inside the trusted
        tailnet boundary instead of falling through to LAN search domains.
      '';
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
}
