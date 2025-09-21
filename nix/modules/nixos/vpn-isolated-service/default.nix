{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.vpn-isolated-service;

  # Built-in IP display service script
  ipDisplayScript = ./ip-display-service.py;
in {
  options.mountainous.vpn-isolated-service = {
    enable = mkEnableOption "VPN-isolated service management";

    lib = mkOption {
      type = types.attrs;
      readOnly = true;
      description = "Library of built-in scripts and utilities";
      default = {
        inherit ipDisplayScript;
      };
    };

    namespaces = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          wireguardConfigFile = mkOption {
            type = types.path;
            description = "Path to WireGuard configuration file for this namespace";
            example = "/run/secrets/proton";
          };

          accessibleFrom = mkOption {
            type = types.listOf types.str;
            default = [
              "192.168.0.0/16"
              "10.0.0.0/8"
              "172.16.0.0/12"
            ];
            description = "Network ranges that can access services in this VPN namespace";
            example = [
              "192.168.0.0/16"
              "10.0.0.0/8"
              "100.64.0.0/10" # Tailscale network
            ];
          };

          portMappings = mkOption {
            type = types.listOf (types.submodule {
              options = {
                from = mkOption {
                  type = types.int;
                  description = "External port to map from";
                  example = 8888;
                };

                to = mkOption {
                  type = types.int;
                  description = "Internal VPN namespace port to map to";
                  example = 8888;
                };

                protocol = mkOption {
                  type = types.enum ["tcp" "udp" "both"];
                  default = "tcp";
                  description = "Protocol for port mapping";
                };
              };
            });
            default = [];
            description = "Port mappings for this VPN namespace";
            example = [
              {
                from = 8888;
                to = 8888;
                protocol = "tcp";
              }
              {
                from = 9999;
                to = 9999;
                protocol = "udp";
              }
            ];
          };
        };
      });
      default = {};
      description = "VPN namespace configurations";
      example = {
        vpn = {
          wireguardConfigFile = "/run/secrets/proton";
          accessibleFrom = [
            "192.168.0.0/16"
            "100.64.0.0/10" # Tailscale network
          ];
          portMappings = [
            {
              from = 8888;
              to = 8888;
            }
          ];
        };
      };
    };

    services = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          vpnNamespace = mkOption {
            type = types.str;
            description = "Name of the VPN namespace this service should run in";
            example = "vpn";
          };

          script = mkOption {
            type = types.lines;
            description = "Script to run for this service";
            example = ''
              ${pkgs.python3}/bin/python3 /path/to/your/script.py
            '';
          };

          environment = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "Environment variables for the service";
            example = {
              "LISTEN_HOST" = "192.168.15.1";
              "LISTEN_PORT" = "8888";
            };
          };

          description = mkOption {
            type = types.str;
            default = "";
            description = "Description for the systemd service";
            example = "VPN IP verification service";
          };

          after = mkOption {
            type = types.listOf types.str;
            default = ["network.target"];
            description = "Systemd units this service should start after";
          };

          wantedBy = mkOption {
            type = types.listOf types.str;
            default = ["multi-user.target"];
            description = "Systemd targets that should want this service";
          };

          serviceConfig = mkOption {
            type = types.attrsOf (types.oneOf [types.str types.int types.bool types.path (types.listOf types.str)]);
            default = {
              Type = "simple";
              Restart = "always";
              RestartSec = "10";
            };
            description = "Additional systemd service configuration";
          };
        };
      });
      default = {};
      description = "Services to run in VPN namespaces";
      example = {
        ip-display = {
          vpnNamespace = "vpn";
          script = ''
            ${pkgs.python3}/bin/python3 ${./ip-display-service.py}
          '';
          description = "Simple HTTP server displaying public IP";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # Ensure WireGuard is enabled
    networking.wireguard.enable = true;

    # Configure VPN namespaces using VPN-Confinement
    vpnNamespaces =
      lib.mapAttrs (namespaceName: namespaceConfig: {
        enable = true;
        inherit (namespaceConfig) wireguardConfigFile accessibleFrom portMappings;
      })
      cfg.namespaces;

    # Create systemd services for each service configuration
    systemd.services =
      lib.mapAttrs' (serviceName: serviceConfig: {
        name = "vpn-isolated-${serviceName}";
        value = {
          description =
            if serviceConfig.description != ""
            then serviceConfig.description
            else "VPN-isolated service: ${serviceName}";

          inherit (serviceConfig) after wantedBy;

          # Merge default and custom service configuration
          serviceConfig =
            serviceConfig.serviceConfig
            // {
              Type = serviceConfig.serviceConfig.Type or "simple";
              Restart = serviceConfig.serviceConfig.Restart or "always";
              RestartSec = serviceConfig.serviceConfig.RestartSec or "10";
            };

          # Enable VPN confinement for this service
          vpnConfinement = {
            enable = true;
            vpnNamespace = serviceConfig.vpnNamespace;
          };

          # Set up environment variables
          environment = serviceConfig.environment;

          # Use the provided script
          script = serviceConfig.script;
        };
      })
      cfg.services;

    # Validate that all services reference existing namespaces
    assertions = let
      definedNamespaces = builtins.attrNames cfg.namespaces;
      serviceNamespaces = lib.mapAttrsToList (_: service: service.vpnNamespace) cfg.services;
      invalidNamespaces = lib.filter (ns: !(builtins.elem ns definedNamespaces)) serviceNamespaces;
    in [
      {
        assertion = invalidNamespaces == [];
        message = ''
          VPN-isolated services reference undefined namespaces: ${lib.concatStringsSep ", " invalidNamespaces}
          Defined namespaces: ${lib.concatStringsSep ", " definedNamespaces}
        '';
      }
    ];
  };
}
