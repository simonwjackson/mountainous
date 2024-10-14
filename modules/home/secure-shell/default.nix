{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption;

  cfg = config.mountainous.secure-shell;
in {
  options.mountainous.secure-shell = {
    enable = mkEnableOption "Whether to enable ssh user configs";
  };

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      compression = true;
      controlMaster = "auto";
      forwardAgent = true;
      matchBlocks = {
        "*" = {
          sendEnv = ["TZ"];
        };

        # TODO: generate from hosts names
        "usu naka sobo bandi" = {
          user = "nix-on-droid";
          port = 2222;
        };

        # TODO: generate from hosts names
        "aka asahi fiji haku kita nyu rakku unzen yari zao" = {
          user = "simonwjackson";
          port = 22;
        };
      };
    };
  };
}
