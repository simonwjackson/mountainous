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
          PermitRootLogin = "no";
        };
      };

      networking.networkmanager.enable = true;

      system.stateVersion = "25.05";
    };
}
