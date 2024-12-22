{
  config,
  lib,
  options,
  inputs,
  system,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption;
  inherit (builtins) filter pathExists;
  inherit (lib.attrsets) mapAttrs' nameValuePair;
  inherit (lib.modules) mkDefault;
  inherit (lib.strings) removeSuffix;

  secretsFile = "${cfg.secretsDir}/secrets.nix";

  cfg = config.mountainous.agenix;
in {
  options.mountainous.agenix = {
    enable = mkEnableOption "Whether to enable agenix";
    secretsDir = mkOption {
      type = lib.types.path;
      description = "";
    };
    user = mkOption {
      type = lib.types.str;
      default = config.mountainous.user.name;
      description = "";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.agenix.packages."${system}".default
    ];
    age = {
      identityPaths =
        options.age.identityPaths.default
        ++ [
          # TODO: Pull this value from somewhere else in the config
          "/home/${cfg.user}/.ssh/id_rsa"
          "/tundra/igloo/id_rsa"
        ];

      secrets =
        if pathExists secretsFile
        then
          mapAttrs' (n: _:
            nameValuePair (removeSuffix ".age" n) {
              file = "${cfg.secretsDir}/${n}";
              group = "users";
              owner = mkDefault cfg.user;
            }) (import secretsFile)
        else {};
    };
  };
}
