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
  # networking.hostName = "yari";
  mountainous = {
    boot.type = "bios";
    printing.enable = false;
    networking = {
      tailscaled.exit-node = true;
      core.names = [
        {
          name = "eth";
          mac = "00:16:3e:c6:25:3e";
        }
      ];
    };
  };

  # age.secrets.yabashi-syncthing-key.file = ../../../secrets/yabashi-syncthing-key.age;
  # age.secrets.yabashi-syncthing-cert.file = ../../../secrets/yabashi-syncthing-cert.age;
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

  # HACK: https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/issues/275#note_1746383655
  # services.dovecot2.sieve.extensions = lib.mkForce ["fileinto"];
  # services.dovecot2.sieve.globalExtensions = lib.mkForce ["fileinto"];

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
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [80 443];

  system.stateVersion = "23.11";
}
