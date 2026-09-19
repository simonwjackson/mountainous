# A headless server that runs unattended without a local display or seat.
{
  nixos.modules.server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # A server must stay awake unattended. Ignore lid switches and disable sleep.
      systemd.targets.sleep.enable = lib.mkDefault false;
      systemd.targets.suspend.enable = lib.mkDefault false;
      systemd.targets.hibernate.enable = lib.mkDefault false;
      systemd.targets.hybrid-sleep.enable = lib.mkDefault false;

      services.logind.settings.Login = {
        HandleLidSwitch = lib.mkDefault "ignore";
        HandleLidSwitchDocked = lib.mkDefault "ignore";
      };

      boot.kernelParams = [ "consoleblank=300" ];

      # Headless servers do not need Bluetooth.
      hardware.bluetooth.enable = lib.mkForce false;

      # Enable Tailscale subnet routing / exit node capabilities.
      mountainous.tailscale.routingFeatures = lib.mkDefault "both";

      # Weekly store garbage collection.
      nix.gc = {
        automatic = lib.mkDefault true;
        dates = lib.mkDefault "weekly";
        options = lib.mkDefault "--delete-older-than 14d";
      };

      environment.systemPackages = with pkgs; [
        htop
        tmux
        curl
        git
        jq
      ];
    };
}
