{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}: {
  services = {
    gotify = {
      enable = true;
      port = 8084;
    };

    nginx = {
      virtualHosts = {
        "notify.simonwjackson.io" = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://[::1]:${toString config.services.gotify.port}";
            # INFO: Webdockets needs 'upgrade'
            extraConfig = ''
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "Upgrade";
            '';
          };
        };
      };
    };
  };
}
