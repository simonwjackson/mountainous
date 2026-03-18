{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkDefault mkIf;
  cfg = config.mountainous.presets.server;
in {
  config = mkIf cfg.enable {
    mountainous.features.atuin.enable = mkDefault true;
    mountainous.features.ssh.server.enable = mkDefault true;
    mountainous.features.tailscale.extraSetFlags = mkDefault ["--netfilter-mode=nodivert"];

    nix.gc = {
      automatic = mkDefault true;
      dates = mkDefault "daily";
      options = mkDefault "--delete-older-than 7d";
    };

    environment.systemPackages = with pkgs; [
      vim
      curl
      htop
      git
      jq
    ];
  };
}
