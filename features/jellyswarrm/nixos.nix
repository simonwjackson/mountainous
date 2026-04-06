{
  config,
  lib,
  ...
}: let
  inherit (lib) attrByPath mkIf mkMerge optional;
  cfg = config.mountainous.features.jellyswarrm;
  tsnetProxyEnabled = attrByPath ["mountainous" "features" "tsnet-proxy" "enable"] false config;
in {
  config = mkIf cfg.enable (mkMerge [
    {
      assertions =
        []
        ++ optional cfg.proxy.enable {
          assertion = tsnetProxyEnabled;
          message = "mountainous.features.jellyswarrm.proxy requires mountainous.features.tsnet-proxy.enable = true";
        };

      services.jellyswarrm = {
        enable = true;
        inherit (cfg) port username openFirewall;
        passwordFile = cfg.passwordFile;
      };
    }

    (mkIf cfg.proxy.enable {
      mountainous.features.tsnet-proxy.services.jellyswarrm = {
        host = "127.0.0.1";
        hostname = cfg.proxy.hostname;
        openFirewall = cfg.proxy.openFirewall;
        port = cfg.port;
        protocol = cfg.proxy.protocol;
      };
    })
  ]);
}
