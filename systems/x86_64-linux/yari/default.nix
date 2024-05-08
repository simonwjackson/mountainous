{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./hardware.nix
    ./matrix.nix
    ./gotify.nix
  ];

  zramSwap.enable = true;
  networking.hostName = "yari";
  mountainous.networking.tailscaled.exit-node = true;
  mountainous.networking.core.names = [
    {
      name = "eth";
      mac = "00:16:3e:c6:25:3e";
    }
  ];

  # age.secrets.yabashi-syncthing-key.file = ../../../secrets/yabashi-syncthing-key.age;
  # age.secrets.yabashi-syncthing-cert.file = ../../../secrets/yabashi-syncthing-cert.age;
  age.secrets.user-simonwjackson-email.file = ../../../secrets/user-simonwjackson-email.age;
  age.secrets.ntfy-htpasswd.file = ../../../secrets/ntfy-htpasswd.age;

  # boot = {
  #   tmp.cleanOnBoot = true;
  # };
  #
  # services.syncthing = {
  #   enable = true;
  #   # key = config.age.secrets.yabashi-syncthing-key.path;
  #   # cert = config.age.secrets.yabashi-syncthing-cert.path;
  #
  #   settings.paths = {
  #     #   documents = "/home/simonwjackson/documents";
  #     #   notes = "/home/simonwjackson/notes";
  #   };
  # };
  #
  # services.taskserver.enable = true;
  # services.taskserver.fqdn = config.networking.hostName;
  # services.taskserver.listenHost = "::";
  # services.taskserver.organisations.mountainous.users = ["simonwjackson"];

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

  #########

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
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [80 443];

  ########
  # system.activationScripts = {
  #   ntfyUsers = {
  #     text = "NTFY_PASSWORD=$(cat ${config.age.secrets.ntfy-htpasswd.path}) ${lib.getExe pkgs.ntfy-sh} user add --ignore-exists --role=admin simonwjackson";
  #     deps = [];
  #   };
  # };

  # services.ntfy-sh = {
  #   enable = true;
  #   settings = {
  #     auth-default-access = "deny-all";
  #     listen-http = ":8888";
  #     base-url = "https://notify.simonwjackson.io";
  #     behind-proxy = true;
  #   };
  # };
  #
  # services.nginx = {
  #   virtualHosts = {
  #     "notify.simonwjackson.io" = {
  #       enableACME = true;
  #       forceSSL = true;
  #       locations."/" = {
  #         proxyPass = "http://[::1]:8888";
  #         # INFO: Webdockets needs 'upgrade'
  #         extraConfig = ''
  #           proxy_http_version 1.1;
  #           proxy_set_header Upgrade $http_upgrade;
  #           proxy_set_header Connection "Upgrade";
  #         '';
  #       };
  #     };
  #   };
  # };

  #######

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11";
}
