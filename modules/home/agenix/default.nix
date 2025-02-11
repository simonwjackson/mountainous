{
  config,
  lib,
  options,
  inputs,
  pkgs,
  system,
  ...
}: let
  inherit (lib) mkEnableOption mkOption;
  inherit (builtins) filter pathExists;
  inherit (lib.attrsets) mapAttrs' nameValuePair;
  inherit (lib.modules) mkDefault;
  inherit (lib.strings) removeSuffix;

  cfg = config.mountainous.agenix;
in {
  imports = [
    inputs.agenix.homeManagerModules.age
  ];

  options.mountainous.agenix = {
    enable = mkEnableOption "Whether to enable agenix";

    secretsDir = mkOption {
      type = lib.types.str;
      default = "${inputs.secrets}/agenix";
      description = "Directory containing agenix secrets";
    };

    secretSymlinks = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create symlinks for age secrets by default.";
    };

    secretMode = lib.mkOption {
      type = lib.types.str;
      default = "0400";
      description = "Default mode for age secrets.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      inputs.agenix.packages.${system}.default
    ];

    age = {
      identityPaths =
        options.age.identityPaths.default
        ++ [
          # TODO: Pull this value from somewhere else in the config
          "/tundra/igloo/id_rsa"
        ];

      secrets = let
        secretsFile = "${cfg.secretsDir}/secrets.nix";
      in
        if pathExists secretsFile
        then
          mapAttrs' (key: _:
            nameValuePair (removeSuffix ".age" key) {
              file = "${cfg.secretsDir}/${key}";
              symlink = cfg.secretSymlinks;
              mode = cfg.secretMode;
            }) (import secretsFile)
        else {};
    };
  };
}
