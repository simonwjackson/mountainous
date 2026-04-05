{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.vpn-ns;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.vpn-ns = {
    enable = mkEnableOption "VPN namespace for leak-resistant service isolation";

    configFile = mkOption {
      type = types.path;
      description = "Path to the WireGuard configuration file used by vpn-ns.";
      example = "config.age.secrets.\"fastest-vpn\".path";
    };

    localNetworks = mkOption {
      type = types.listOf types.str;
      default = ["192.168.0.0/16"];
      description = "CIDRs that should bypass the tunnel via the host veth route.";
    };

    vethAddress = mkOption {
      type = types.str;
      default = "10.200.200.2";
      readOnly = true;
      description = "Address of the namespace-side veth interface.";
    };

    tailscaleHosts = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["tv.example.ts.net" "movies.example.ts.net"];
      description = ''
        Tailscale MagicDNS hostnames to resolve from the host and inject as
        static /etc/hosts entries inside the VPN namespace. This allows
        namespaced services to reach Tailscale peers by DNS name without
        adding a DNS resolver that would leak queries outside the VPN tunnel.

        Entries are resolved at namespace setup time. Restart vpn-ns to
        refresh if a peer's Tailscale IP changes.
      '';
    };

    services = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          enable = mkEnableOption "run ${name} inside the VPN namespace";

          unit = mkOption {
            type = types.str;
            default = "${name}.service";
            description = "Systemd unit name to run inside the VPN namespace.";
          };

          port = mkOption {
            type = types.port;
            description = "Port the service listens on inside the VPN namespace.";
          };

          tailscale = {
            enable = mkEnableOption "expose the service through tsnet-proxy";

            hostname = mkOption {
              type = types.str;
              default = name;
              description = "Tailscale hostname for this proxied service.";
            };

            protocol = mkOption {
              type = types.enum ["http" "https"];
              default = "http";
              description = "Backend protocol used by tsnet-proxy.";
            };
          };
        };
      }));
      default = {};
      description = "Services that must run inside the VPN namespace.";
    };
  };
}
