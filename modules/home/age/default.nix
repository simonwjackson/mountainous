{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption;

  cfg = config.mountainous.agenix;
in {
  options.mountainous.agenix = {
    enable = mkEnableOption "Whether to enable agenix";
  };

  config = lib.mkIf cfg.enable {
    age = {
      identityPaths =
        options.age.identityPaths.default
        ++ [
          # TODO: Pull this value from somewhere else in the config
          "${config.home.homeDirectory}/.ssh/agenix"
        ];
    };
  };
}
