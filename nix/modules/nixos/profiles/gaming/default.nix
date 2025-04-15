{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.mountainous.profiles.gaming;
in {
  options.mountainous.profiles.gaming = {
    enable = mkEnableOption "Whether to enable the gaming profile";
  };

  config = mkIf cfg.enable {
    mountainous = {
      steam.enable = true;
    };

    # Allow uinput devices to be used by non-root users
    services.udev.extraRules = ''
      SUBSYSTEM=="misc", KERNEL=="uinput", OPTIONS+="static_node=uinput", TAG+="uaccess"
    '';

    environment.systemPackages = with pkgs; [
      # inputs.elevate.packages.${system}.moonbeam
      # inputs.elevate.packages.x86_64-linux.moonbeam
      # mangohud_git
      # gamescope-wsi_git
      # gamescope_git
      dolphin-emu
      rpcs3
      cemu
      ryujinx
      retroarch-full
    ];

    # BUG: if dirs dont exist, they are owned by root
    # fileSystems = {
    #   "${share}/dolphin-emu/GC" = {
    #     device = "${cfg.saves}/nintendo-gamecube/";
    #     options = ["bind"];
    #   };
    #
    #   "${share}/dolphin-emu/Wii/title" = {
    #     device = "${cfg.saves}/nintendo-wii/";
    #     options = ["bind"];
    #   };
    #
    #   "${share}/Cemu/mlc01/usr" = {
    #     device = "${cfg.saves}/nintendo-wiiu/";
    #     options = ["bind"];
    #   };
    #
    #   # "/home/${config.mountainous.user.name}/.config/Ryujinx/bis" = {
    #   "/home/simonwjackson/.config/Ryujinx/bis" = {
    #     device = "${cfg.saves}/nintendo-switch";
    #     options = ["bind"];
    #   };
    # };
  };
}
