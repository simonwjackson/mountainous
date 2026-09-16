# Everything every machine gets.
{
  nixos.modules.base =
    { lib, ... }:
    {
      boot.loader.systemd-boot.enable = lib.mkDefault true;
      boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [ "@wheel" ];
      };

      time.timeZone = lib.mkDefault "America/New_York";
      i18n.defaultLocale = "en_US.UTF-8";

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          # Key-only root. "no" blocks remote deploys entirely, which is how
          # ridge ended up reachable only as simon with an interactive sudo.
          PermitRootLogin = "prohibit-password";
        };
      };

      networking.networkmanager.enable = true;

      system.stateVersion = "25.05";
    };
}
