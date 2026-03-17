{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.features.tsnet-proxy;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.tsnet-proxy = {
    enable = mkEnableOption "tsnet-based Tailscale proxy services";

    package = mkOption {
      type = types.package;
      description = "tsnet-proxy package to use";
    };

    authKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Default Tailscale auth key file for all services";
    };

    services = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          hostname = mkOption {
            type = types.str;
            description = "Tailscale hostname for this proxy node";
          };

          protocol = mkOption {
            type = types.enum ["http" "https"];
            default = "http";
          };

          port = mkOption {
            type = types.int;
            description = "Backend port";
          };

          host = mkOption {
            type = types.str;
            default = "localhost";
          };

          authKeyFile = mkOption {
            type = types.nullOr types.path;
            default = null;
          };

          listenPort = mkOption {
            type = types.str;
            default = "443";
          };

          openFirewall = mkOption {
            type = types.bool;
            default = false;
            description = "Open the host firewall for this proxy listener.";
          };
        };
      });
      default = {};
    };
  };
}
