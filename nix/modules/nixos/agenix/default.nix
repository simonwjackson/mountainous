{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  
  cfg = config.mountainous.agenix;
  
  # Path to secrets directory
  secretsDir = ../../../../secrets/agenix;
  
  # Function to check if a file exists
  fileExists = path: builtins.pathExists path;
  
  # Function to auto-discover .age files from secrets directory
  discoverSecrets = let
    # Check if secrets directory exists
    secretsDirExists = fileExists secretsDir;
    
    # Read directory contents if it exists
    secretFiles = 
      if secretsDirExists
      then 
        let
          dirContent = builtins.readDir secretsDir;
          ageFiles = lib.filterAttrs (name: type: 
            type == "regular" && lib.hasSuffix ".age" name
          ) dirContent;
        in
          builtins.attrNames ageFiles
      else [];
    
    # Convert file names to secret configuration
    # Strip .age extension for secret names
    secretsConfig = builtins.listToAttrs (map (fileName: {
      name = lib.removeSuffix ".age" fileName;
      value = {
        file = secretsDir + "/${fileName}";
        owner = cfg.secretsOwner;
        group = cfg.secretsGroup;
        mode = cfg.secretsMode;
      };
    }) secretFiles);
  in
    secretsConfig;
    
  # Import secrets.nix if it exists
  secretsNix = 
    if fileExists (secretsDir + "/secrets.nix")
    then import (secretsDir + "/secrets.nix")
    else {};
    
  # Available secrets from auto-discovery
  autoDiscoveredSecrets = discoverSecrets;
  
  # Default user from mountainous.user module if available
  defaultUser = 
    if config ? mountainous.user && config.mountainous.user.enable
    then config.mountainous.user.name
    else "simonwjackson";
in {
  imports = [
    inputs.agenix.nixosModules.default
  ];

  options.mountainous.agenix = {
    enable = mkEnableOption "Whether to enable agenix secrets management for NixOS";
    
    identityPaths = mkOption {
      type = types.listOf types.str;
      default = [
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_ed25519_key"
        "/tundra/igloo/id_rsa"
      ];
      description = "Paths to identity files for decrypting secrets";
    };
    
    secretsDir = mkOption {
      type = types.str;
      default = "/run/agenix";
      description = "Directory where secrets are symlinked";
    };
    
    secretsOwner = mkOption {
      type = types.str;
      default = defaultUser;
      description = "Owner of decrypted secrets";
    };
    
    secretsGroup = mkOption {
      type = types.str;
      default = "users";
      description = "Group of decrypted secrets";
    };
    
    secretsMode = mkOption {
      type = types.str;
      default = "400";
      description = "Permissions mode of decrypted secrets";
    };
    
    installCli = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install the agenix CLI tool system-wide";
    };
  };

  config = mkIf cfg.enable {
    # Configure agenix
    age = {
      identityPaths = cfg.identityPaths;
      secretsDir = cfg.secretsDir;
      secrets = autoDiscoveredSecrets;
    };
    
    # Install agenix CLI tool system-wide
    environment.systemPackages = mkIf cfg.installCli [
      inputs.agenix.packages.${pkgs.system}.default
    ];
  };
}