{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault mkIf mapAttrs;
  cfg = config.mountainous.features.secrets;
  secretsLib = import ./lib.nix {inherit lib;};

  discovered = secretsLib.discover {
    secretsRoot = ../../secrets;
    hostname = cfg.hostname;
  };
in {
  config = lib.mkMerge [
    # Always set platform defaults (even before enable is evaluated).
    {
      mountainous.features.secrets.enable = mkDefault true;
      mountainous.features.secrets.hostname = mkDefault config.networking.hostName;
    }

    # When enabled, declare all discovered secrets in agenix and expose paths.
    (mkIf cfg.enable {
      age.secrets = mapAttrs (_name: secret: {
        file = mkDefault secret.file;
        owner = mkDefault secret.owner;
        group = mkDefault secret.group;
        mode = mkDefault secret.mode;
      }) discovered;

      mountainous.features.secrets.path =
        mapAttrs (name: _: config.age.secrets.${name}.path) discovered;
    })
  ];
}
