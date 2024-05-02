{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}: let
  cfg = config.mountainous.gaming;
  snowscape = "/glacier/snowscape";
in {
  options.mountainous.gaming = {
    enable = lib.mkEnableOption "Enable emulation";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.suyu.packages."${system}".suyu
      pkgs.cemu
      pkgs.retroarchFull
      pkgs.dolphinEmu
      pkgs.rpcs3
    ];

    # BUG: if dirs dont exist, they are owned by root
    fileSystems = {
      "/home/simonwjackson/.local/share/dolphin-emu/GC" = {
        device = "${snowscape}/gaming/profiles/simonwjackson/progress/saves/nintendo-gamecube/";
        options = ["bind"];
      };

      "/home/simonwjackson/.local/share/dolphin-emu/Wii/title" = {
        device = "${snowscape}/gaming/profiles/simonwjackson/progress/saves/nintendo-wii/";
        options = ["bind"];
      };

      "/home/simonwjackson/.local/share/Cemu/mlc01/usr" = {
        device = "${snowscape}/gaming/profiles/simonwjackson/progress/saves/nintendo-wiiu/";
        options = ["bind"];
      };

      "/home/simonwjackson/.local/share/yuzu/sdmc" = {
        device = "${snowscape}/gaming/profiles/simonwjackson/progress/saves/nintendo-switch/sdmc";
        options = ["bind"];
      };

      "/home/simonwjackson/.local/share/yuzu/shader" = {
        device = "${snowscape}/gaming/launchers/yuzu/shader";
        options = ["bind"];
      };

      "/home/simonwjackson/.local/share/yuzu/keys" = {
        device = "${snowscape}/gaming/systems/nintendo-switch/keys";
        options = ["bind"];
      };

      "/home/simonwjackson/.local/share/yuzu/nand" = {
        device = "${snowscape}/gaming/profiles/simonwjackson/progress/saves/nintendo-switch/nand";
        options = ["bind"];
      };
    };
  };
}
