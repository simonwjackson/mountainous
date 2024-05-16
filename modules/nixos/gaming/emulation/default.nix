{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}: let
  inherit (lib) mkEnableOption mkOption;

  cfg = config.mountainous.gaming.emulation;
  snowscape = "/glacier/snowscape";
  saves = "${snowscape}/gaming/profiles/${config.mountainous.user.name}/progress/saves";
  share = "/home/${config.mountainous.user.name}/.local/share";
in {
  options.mountainous.gaming.emulation = {
    enable = mkEnableOption "Whether to enable emulation";
    gen-8 = mkEnableOption "Whether to enable the 8th generation of consoles";
    gen-7 = mkEnableOption "Whether to enable the 7th generation of consoles";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = let
      gen-7 = [
        pkgs.dolphinEmu
        pkgs.rpcs3
      ];
      gen-8 = [
        pkgs.cemu
        inputs.suyu.packages."${system}".suyu
      ];
    in
      [
        pkgs.retroarchFull
      ]
      ++ lib.optionals cfg.gen-8 gen-7
      ++ lib.optionals cfg.gen-8 gen-8;
    # BUG: if dirs dont exist, they are owned by root
    fileSystems = {
      "${share}/dolphin-emu/GC" = {
        device = "${saves}/nintendo-gamecube/";
        options = ["bind"];
      };

      "${share}/dolphin-emu/Wii/title" = {
        device = "${saves}/nintendo-wii/";
        options = ["bind"];
      };

      "${share}/Cemu/mlc01/usr" = {
        device = "${saves}/nintendo-wiiu/";
        options = ["bind"];
      };

      "${share}/yuzu/sdmc" = {
        device = "${saves}/nintendo-switch/sdmc";
        options = ["bind"];
      };

      "${share}/yuzu/shader" = {
        device = "${snowscape}/gaming/launchers/yuzu/shader";
        options = ["bind"];
      };

      "${share}/yuzu/keys" = {
        device = "${snowscape}/gaming/systems/nintendo-switch/keys";
        options = ["bind"];
      };

      "${share}/yuzu/nand" = {
        device = "${saves}/nintendo-switch/nand";
        options = ["bind"];
      };
    };
  };
}
