{
  config,
  inputs,
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;

  cfg = config.mountainous.agenix;

  # Path to secrets directory
  secretsDir = ../../../../secrets/agenix;

  # Function to check if a file exists
  fileExists = path: builtins.pathExists path;

  # Function to auto-discover .age files from secrets directory
  # Include user-specific secrets and atuin secrets for home-manager
  discoverSecrets = let
    # Check if secrets directory exists
    secretsDirExists = fileExists secretsDir;

    # Read directory contents if it exists
    secretFiles =
      if secretsDirExists
      then let
        dirContent = builtins.readDir secretsDir;
        ageFiles =
          lib.filterAttrs (
            name: type:
              type == "regular" && lib.hasSuffix ".age" name
          )
          dirContent;
        # Include user-specific secrets (starting with "user-") and atuin secrets
        allowedSecrets =
          lib.filterAttrs (
            name: type:
              lib.hasPrefix "user-" name
              || lib.hasPrefix "atuin_" name
          )
          ageFiles;
      in
        builtins.attrNames allowedSecrets
      else [];

    # Convert file names to secret configuration
    # Strip .age extension for secret names
    secretsConfig = builtins.listToAttrs (map (fileName: {
        name = lib.removeSuffix ".age" fileName;
        value = {
          file = secretsDir + "/${fileName}";
        };
      })
      secretFiles);
  in
    secretsConfig;

  # Import secrets.nix if it exists
  secretsNix =
    if fileExists (secretsDir + "/secrets.nix")
    then import (secretsDir + "/secrets.nix")
    else {};

  # Available secrets from auto-discovery
  autoDiscoveredSecrets = discoverSecrets;
in {
  imports = [
    inputs.agenix.homeManagerModules.default
  ];

  options.mountainous.agenix = {
    enable = mkEnableOption "Whether to enable agenix secrets management for home-manager";

    identityPaths = mkOption {
      type = types.listOf types.str;
      default = [
        "${config.home.homeDirectory}/.ssh/id_rsa"
        "${config.home.homeDirectory}/.ssh/id_ed25519"
        "/tundra/igloo/id_rsa"
      ];
      description = "Paths to identity files for decrypting secrets";
    };

    secretsDir = mkOption {
      type = types.str;
      default = 
        if osConfig ? users.users.${config.home.username}.uid
        then "/run/user/${toString osConfig.users.users.${config.home.username}.uid}/agenix"
        else "$XDG_RUNTIME_DIR/agenix";
      description = "Directory where secrets are symlinked";
    };

    installCli = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install the agenix CLI tool";
    };
  };

  config = mkIf cfg.enable {
    # Configure agenix
    age = {
      identityPaths = cfg.identityPaths;
      secretsDir = cfg.secretsDir;
      secrets = autoDiscoveredSecrets;
    };

    # Install agenix CLI tool
    home.packages = mkIf cfg.installCli [
      inputs.agenix.packages.${pkgs.system}.default
    ];
  };
}
