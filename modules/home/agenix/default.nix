{
  config,
  lib,
  options,
  inputs,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption;
  # inherit (inputs) ragenix;
  inherit (builtins) filter pathExists;
  inherit (lib.attrsets) mapAttrs' nameValuePair;
  inherit (lib.modules) mkDefault;
  inherit (lib.strings) removeSuffix;

  secretsDir = "${inputs.secrets}/agenix/";
  secretsFile = "${secretsDir}/secrets.nix";

  cfg = config.mountainous.agenix;
in {
  imports = [
    inputs.agenix.homeManagerModules.age
  ];
  # imports = [ragenix.nixosModules.default];

  options.mountainous.agenix = {
    enable = mkEnableOption "Whether to enable agenix";
  };

  config = lib.mkIf cfg.enable {
    # environment.systemPackages = [ragenix.packages.x86_64-linux.default];
    age = {
      identityPaths =
        options.age.identityPaths.default;
      # ++ [
      #   "${config.home.homeDirectory}/.ssh/agenix"
      # ];

      secrets =
        if pathExists secretsFile
        then
          mapAttrs' (n: _:
            nameValuePair (removeSuffix ".age" n) {
              file = "${secretsDir}/${n}";
            }) (import secretsFile)
        else {};
    };

    # age.identityPaths = options.age.identityPaths.default ++ (filter pathExists [
    #   "${config.user.home}/.ssh/id_ed25519"
    #   "${config.user.home}/.ssh/id_rsa"
    # ]);
  };
}
