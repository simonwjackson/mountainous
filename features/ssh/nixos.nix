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

    programs.ssh.extraConfig = mkDefault ''
      IgnoreUnknown WarnWeakCrypto
      WarnWeakCrypto no
    '';

    services.openssh = {
      enable = mkDefault true;
      settings = {
        PermitRootLogin = mkDefault "prohibit-password";
        PasswordAuthentication = mkDefault false;
        ClientAliveInterval = mkDefault 30;
        ClientAliveCountMax = mkDefault 3;
      };
    };

    programs.mosh.enable = mkDefault true;

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
