# secrets.nix - Helper library for declaring agenix secrets
#
# This library provides utilities for modules to self-declare their secret requirements
# with automatic ownership/permission inference based on directory structure.
#
# Directory structure -> Ownership mapping:
#   secrets/system/**     -> root:root (400)
#   secrets/hosts/**      -> root:root (400)
#   secrets/user/{user}/** -> {user}:users (400)
#
# Usage in a module:
#   let
#     secretsLib = import ../../../lib/secrets.nix { inherit lib; };
#   in {
#     age.secrets.my-secret = secretsLib.mkSecret {
#       path = "system/networking/my-secret";
#     };
#   }
{lib}: let
  # Base path to secrets directory (relative to nix/lib/)
  secretsRoot = ../../secrets;

  # Determine ownership from path based on directory structure
  ownershipFromPath = path: let
    parts = lib.splitString "/" path;
    category =
      if builtins.length parts > 0
      then builtins.elemAt parts 0
      else "system";
  in
    if category == "user" && builtins.length parts > 1
    then {
      # User secrets: owned by the username in path
      owner = builtins.elemAt parts 1;
      group = "users";
      mode = "400";
    }
    else {
      # System, hosts, and other secrets: owned by root
      owner = "root";
      group = "root";
      mode = "400";
    };

  # Create a secret declaration with automatic ownership inference
  # Args:
  #   path: Relative path from secrets/ (without .age extension)
  #   owner: Optional override for owner
  #   group: Optional override for group
  #   mode: Optional override for mode
  #   rekeyFile: Optional - use rekeyFile instead of file (for agenix-rekey)
  mkSecret = {
    path,
    owner ? null,
    group ? null,
    mode ? null,
    useRekey ? false,
  }: let
    defaults = ownershipFromPath path;
    secretPath = secretsRoot + "/${path}.age";
  in
    {
      owner =
        if owner != null
        then owner
        else defaults.owner;
      group =
        if group != null
        then group
        else defaults.group;
      mode =
        if mode != null
        then mode
        else defaults.mode;
    }
    // (
      if useRekey
      then {rekeyFile = secretPath;}
      else {file = secretPath;}
    );

  # Create a secret for a specific hostname (e.g., syncthing keys)
  # Args:
  #   hostname: The hostname for the secret
  #   name: Secret name (e.g., "syncthing-key")
  #   owner: Optional override for owner
  #   group: Optional override for group
  mkHostSecret = {
    hostname,
    name,
    owner ? null,
    group ? null,
    mode ? null,
    useRekey ? false,
  }:
    mkSecret {
      path = "hosts/${hostname}/${name}";
      inherit owner group mode useRekey;
    };

  # Create a user secret
  # Args:
  #   username: The username
  #   path: Relative path within user directory (e.g., "credentials/github-token")
  mkUserSecret = {
    username,
    path,
    mode ? null,
    useRekey ? false,
  }:
    mkSecret {
      path = "user/${username}/${path}";
      owner = username;
      group = "users";
      inherit mode useRekey;
    };

  # Create a system secret
  # Args:
  #   path: Relative path within system directory (e.g., "networking/tailscale")
  #   owner: Optional override (defaults to root)
  #   group: Optional override (defaults to root)
  mkSystemSecret = {
    path,
    owner ? "root",
    group ? "root",
    mode ? "400",
    useRekey ? false,
  }:
    mkSecret {
      path = "system/${path}";
      inherit owner group mode useRekey;
    };

  # Check if a secret file exists
  secretExists = path: builtins.pathExists (secretsRoot + "/${path}.age");

  # Conditionally create a secret only if it exists
  mkSecretIfExists = args:
    if secretExists args.path
    then mkSecret args
    else null;

  # Filter out null secrets from an attrset
  filterSecrets = secrets:
    lib.filterAttrs (name: value: value != null) secrets;
in {
  inherit
    mkSecret
    mkHostSecret
    mkUserSecret
    mkSystemSecret
    secretExists
    mkSecretIfExists
    filterSecrets
    ownershipFromPath
    secretsRoot
    ;
}
