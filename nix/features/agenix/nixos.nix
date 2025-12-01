{
  config,
  inputs,
  lib,
  pkgs,
  target ? "x86_64-linux",
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkDefault types;

  cfg = config.mountainous.agenix;

  # Import shared options
  sharedOptions = import ./options.nix {inherit lib;};

  # Path to secrets directory (new structure)
  # Go up from nix/features/agenix/ to repo root, then into secrets/
  secretsRoot = ../../../secrets;

  # Master identity for agenix-rekey
  # Using attrset format to specify both identity path and pubkey:
  # - identity: absolute path to private key (tried at runtime for decryption)
  # - pubkey: used for encryption (avoids needing to decrypt the identity)
  masterIdentityPubkey = builtins.readFile (secretsRoot + "/keys/users/rsa.pub");
  masterIdentity = {
    # Try common locations for the user's SSH key
    identity = "/home/simonwjackson/.ssh/id_rsa";
    pubkey = masterIdentityPubkey;
  };

  # Default user from mountainous.user module if available
  defaultUser =
    if config ? mountainous.user && config.mountainous.user.enable
    then config.mountainous.user.name
    else "simonwjackson";

  # Recursively discover .age files in a directory
  discoverSecrets = dir:
    if !builtins.pathExists dir
    then []
    else let
      entries = builtins.readDir dir;
      processEntry = name: type:
        if type == "directory"
        then discoverSecrets (dir + "/${name}")
        else if type == "regular" && lib.hasSuffix ".age" name
        then [
          {
            name = lib.removeSuffix ".age" name;
            file = dir + "/${name}";
          }
        ]
        else [];
    in
      lib.flatten (lib.mapAttrsToList processEntry entries);

  # Auto-discover system secrets (secrets/system/**)
  systemSecrets = discoverSecrets (secretsRoot + "/system");

  # Function to generate autoSecrets based on config (deferred evaluation)
  mkAutoSecrets = cfg_hostname: let
    # Auto-discover host-specific secrets (secrets/hosts/{hostname}/**)
    hostSecrets = discoverSecrets (secretsRoot + "/hosts/${cfg_hostname}");

    # Combine all discovered secrets
    allDiscoveredSecrets = systemSecrets ++ hostSecrets;
  in
    builtins.listToAttrs (map (secret: {
        inherit (secret) name;
        value = {
          rekeyFile = mkDefault secret.file;
          owner = mkDefault "root";
          group = mkDefault "root";
          mode = mkDefault "400";
        };
      })
      allDiscoveredSecrets);
in {
  imports = [
    inputs.agenix.nixosModules.default
    inputs.agenix-rekey.nixosModules.default
  ];

  options.mountainous.agenix =
    sharedOptions
    // {
      hostPubkey = mkOption {
        type = types.nullOr types.str;
        default = let
          hostname = config.networking.hostName;
          hostPubkeyPath = secretsRoot + "/keys/hosts/${target}_${hostname}_ssh_host_rsa_key.pub";
          hostPubkeyExists = builtins.pathExists hostPubkeyPath;
        in
          if hostPubkeyExists
          then builtins.readFile hostPubkeyPath
          else null;
        description = "SSH public key for this host (auto-detected from secrets/keys/hosts/)";
      };

      masterIdentities = mkOption {
        type = types.listOf types.path;
        default = [];
        description = ''
          Paths to master age identities for rekeying secrets.
          When set (non-empty), systems should also import inputs.agenix-rekey.nixosModules.default
          to enable the rekey workflow.
        '';
      };

      identityPaths = mkOption {
        type = types.listOf types.str;
        default =
          [
            "/etc/ssh/ssh_host_rsa_key"
            "/etc/ssh/ssh_host_ed25519_key"
          ]
          ++ (lib.optionals (config.mountainous.impermanence.enable or false) [
            "/tundra/igloo/id_rsa"
          ]);
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
        description = "Default owner of decrypted secrets";
      };

      secretsGroup = mkOption {
        type = types.str;
        default = "users";
        description = "Default group of decrypted secrets";
      };

      secretsMode = mkOption {
        type = types.str;
        default = "400";
        description = "Default permissions mode of decrypted secrets";
      };
    };

  config = mkIf cfg.enable {
    # Configure agenix base settings
    age = {
      identityPaths = cfg.identityPaths;
      secretsDir = cfg.secretsDir;

      # Auto-discovered secrets with mkDefault (can be overridden)
      secrets = mkIf cfg.autoDiscover (mkAutoSecrets config.networking.hostName);

      # agenix-rekey configuration
      rekey = {
        # Master identity - always required by agenix-rekey
        masterIdentities = mkDefault [masterIdentity];

        # Only set the rest of the configuration if we have a real host pubkey
        hostPubkey = mkIf (cfg.hostPubkey != null) (mkDefault cfg.hostPubkey);
        storageMode = mkIf (cfg.hostPubkey != null) (mkDefault "derivation");
      };
    };

    # Install agenix CLI tool system-wide
    environment.systemPackages = mkIf cfg.installCli [
      inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
