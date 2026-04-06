{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.jellyswarrm;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.jellyswarrm = {
    enable = mkEnableOption "Jellyswarrm reverse proxy for merging multiple Jellyfin servers";

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port for the Jellyswarrm web UI and proxy.";
    };

    username = mkOption {
      type = types.str;
      default = "admin";
      description = "Admin username for the Jellyswarrm management UI.";
    };

    passwordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a secret file containing the Jellyswarrm admin password.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the Jellyswarrm port in the firewall.";
    };

    proxy = {
      enable = mkEnableOption "expose Jellyswarrm through tsnet-proxy";

      hostname = mkOption {
        type = types.str;
        default = "watch";
        description = "Tailscale hostname for Jellyswarrm.";
      };

      protocol = mkOption {
        type = types.enum ["http" "https"];
        default = "http";
        description = "Backend protocol used by tsnet-proxy.";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open the host firewall for the tsnet-proxy listener.";
      };
    };
  };
}
