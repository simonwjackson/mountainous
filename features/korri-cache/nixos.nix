{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.mountainous.features.korri-cache;

  # Korri owns these facts. Reading them keeps revocation to one edit in
  # nix/cache/identity.nix there, and keeps this repository from holding a second
  # list of keys that a revoked builder would still be trusted by. The input is a
  # plain data read: no Korri nixpkgs is instantiated by this host.
  cache = inputs.korri-cache.cache;
in {
  config = mkIf cfg.enable {
    nix.settings = {
      substituters = [cache.url];
      trusted-public-keys = cache.publicKeys;
    };
  };
}
