{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.mcp-gateway;
in {
  options.mountainous.mcp-gateway = {
    enable = mkEnableOption "MCP Gateway - nginx reverse proxy for MCP servers";

    port = mkOption {
      type = types.port;
      default = 8090;
      description = "Port for the MCP gateway to listen on";
    };

    servers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          path = mkOption {
            type = types.str;
            description = "URL path prefix for this MCP server (without leading/trailing slash)";
            example = "synapse";
          };

          upstream = mkOption {
            type = types.str;
            description = "Upstream server address";
            example = "http://127.0.0.1:3939";
          };
        };
      });
      default = {};
      description = "MCP servers to proxy";
      example = {
        synapse = {
          path = "synapse";
          upstream = "http://127.0.0.1:3939";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;

      virtualHosts."mcp-gateway" = {
        listen = [
          {
            addr = "127.0.0.1";
            port = cfg.port;
          }
        ];

        locations =
          lib.mapAttrs' (name: serverCfg: {
            name = "/${serverCfg.path}/";
            value = {
              proxyPass = "${serverCfg.upstream}/";
              proxyWebsockets = true;
              extraConfig = ''
                # SSE support
                proxy_buffering off;
                proxy_cache off;
                proxy_read_timeout 86400s;
                proxy_send_timeout 86400s;

                # Headers for SSE (proxy_http_version set by proxyWebsockets)
                proxy_set_header Connection "";
                chunked_transfer_encoding off;

                # CORS headers
                add_header Access-Control-Allow-Origin * always;
                add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
                add_header Access-Control-Allow-Headers "Content-Type" always;
              '';
            };
          })
          cfg.servers;
      };
    };
  };
}
