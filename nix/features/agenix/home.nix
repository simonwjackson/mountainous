{
  config,
  inputs,
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  inherit (lib) mkOption mkIf types;

  cfg = config.mountainous.agenix;
  username = config.home.username;

  # Import shared options
  sharedOptions = import ./options.nix {inherit lib;};

  # Path to secrets directory (new structure)
  # From nix/features/agenix/ we need to go up 3 levels to reach repo root
  secretsRoot = ../../../secrets;
  userSecretsDir = secretsRoot + "/user/${username}";

  # Function to check if a file/path exists
  fileExists = path: builtins.pathExists path;

  # Recursively discover all .age files under a directory
  discoverSecretsRecursive = dir:
    if !fileExists dir
    then []
    else let
      entries = builtins.readDir dir;

      processEntry = name: type:
        if type == "directory"
        then discoverSecretsRecursive (dir + "/${name}")
        else if type == "regular" && lib.hasSuffix ".age" name
        then let
          # Get the relative path from userSecretsDir
          fullPath = dir + "/${name}";
          # Extract just the secret name (last component without .age)
          secretName = lib.removeSuffix ".age" name;
          # Get the subdirectory path for documentation
          subDir = lib.removePrefix (toString userSecretsDir + "/") (toString dir);
        in [
          {
            inherit secretName subDir;
            path = fullPath;
          }
        ]
        else [];
    in
      lib.flatten (lib.mapAttrsToList processEntry entries);

  # Auto-discover secrets from user directory
  discoveredSecrets = discoverSecretsRecursive userSecretsDir;

  # Convert discovered secrets to age.secrets format
  # Use {subdir}_{filename} pattern for nested secrets (e.g., atuin/key.age -> atuin_key)
  autoDiscoveredSecrets = builtins.listToAttrs (map (secret: {
      name =
        if secret.subDir != "" && secret.subDir != (toString userSecretsDir)
        then "${lib.replaceStrings ["/"] ["_"] secret.subDir}_${secret.secretName}"
        else secret.secretName;
      value = {
        file = secret.path;
      };
    })
    discoveredSecrets);

  # Legacy support: also check for old-style secrets if they exist
  oldSecretsDir = ../../secrets/agenix;
  legacySecrets = let
    oldDirExists = fileExists oldSecretsDir;
    secretFiles =
      if oldDirExists
      then let
        dirContent = builtins.readDir oldSecretsDir;
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
  in
    builtins.listToAttrs (map (fileName: {
        name = lib.removeSuffix ".age" fileName;
        value = {
          file = oldSecretsDir + "/${fileName}";
        };
      })
      secretFiles);

  # Merge new and legacy secrets (new takes precedence)
  allSecrets = legacySecrets // autoDiscoveredSecrets;
in {
  imports = [
    inputs.agenix.homeManagerModules.default
  ];

  options.mountainous.agenix =
    sharedOptions
    // {
      # Home-specific options
      identityPaths = mkOption {
        type = types.listOf types.str;
        default =
          [
            "${config.home.homeDirectory}/.ssh/id_rsa"
            "${config.home.homeDirectory}/.ssh/id_ed25519"
          ]
          ++ (lib.optionals (osConfig.mountainous.impermanence.enable or false) [
            "/tundra/igloo/id_rsa"
          ]);
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
    };

  config = mkIf cfg.enable {
    # Configure agenix
    age = {
      identityPaths = cfg.identityPaths;
      secretsDir = cfg.secretsDir;
      secrets = mkIf cfg.autoDiscover allSecrets;
    };

    # Install agenix CLI tool
    home.packages = mkIf cfg.installCli [
      inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
