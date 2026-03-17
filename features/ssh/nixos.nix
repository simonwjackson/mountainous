{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault mkIf;
  cfg = config.mountainous.features.ssh.server;
in {
  config = mkIf cfg.enable {
    home-manager.users.simonwjackson.imports = [
      ./home.nix
    ];

    services.openssh = {
      enable = mkDefault true;
      settings = {
        PermitRootLogin = mkDefault "prohibit-password";
        PasswordAuthentication = mkDefault false;
      };
    };

    services.fail2ban = {
      enable = mkDefault true;
      ignoreIP = mkDefault ["100.64.0.0/10"];
      maxretry = mkDefault 3;
      bantime = mkDefault "1h";
      bantime-increment = {
        enable = mkDefault true;
        maxtime = mkDefault "168h";
      };
    };
  };
}
