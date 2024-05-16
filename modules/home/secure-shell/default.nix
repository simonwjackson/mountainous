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
        "ushiro,ushiro.hummingbird-lake.ts.net,ushiro.mountaino.us" = {
          user = "sjackson217";
        };
      };
    };
  };
}
