{config, ...}: {
  age.secrets.user-simonwjackson-email.file = ../../../secrets/user-simonwjackson-email.age;
  age.secrets.ntfy-htpasswd.file = ../../../secrets/ntfy-htpasswd.age;

  mailserver = {
    enable = true;
    openFirewall = true;
    certificateScheme = "acme-nginx";
    fqdn = "mail.simonwjackson.io";
    domains = ["simonwjackson.io"];
    loginAccounts = {
      # BUG: when modifying, you must build without any accounts and then rebuild with accounts present
      "default@simonwjackson.io" = {
        hashedPasswordFile = config.age.secrets.user-simonwjackson-email.path;
        aliases = ["@simonwjackson.io"];
      };
    };
  };

  security.acme.acceptTerms = true;
  security.acme.defaults.email = "security@simonwjackson.io";

  services.roundcube = {
    enable = true;
    # this is the url of the vhost, not necessarily the same as the fqdn of
    # the mailserver
    hostName = "inbox.simonwjackson.io";
    extraConfig = ''
      $config['smtp_server'] = "tls://${config.mailserver.fqdn}";
      $config['smtp_user'] = "%u";
      $config['smtp_pass'] = "%p";
    '';
  };

  services.nginx.enable = true;
  networking.firewall.allowedTCPPorts = [80 443];
}
