{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}: let
  cfg = config.mountainous.gaming.core;
  flatpak = lib.getExe pkgs.flatpak;
in {
  options.mountainous.gaming.core = {
    enable = lib.mkEnableOption "Enable gaming";
    isHost = lib.mkEnableOption "Whether or not device will be used for game streaming";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      inputs.elevate.packages.${system}.moonbeam
      # mangohud_git
      gamescope-wsi_git
      gamescope_git
    ];

    services.udev.extraRules = ''
      SUBSYSTEM=="misc", KERNEL=="uinput", OPTIONS+="static_node=uinput", TAG+="uaccess"
    '';

    # Switch controllers
    services.joycond.enable = true;
  };
}
