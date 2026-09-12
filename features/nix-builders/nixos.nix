{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.mountainous.features.nix-builders;
  registry = import ./hosts.nix;
in {
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.use != [];
        message = "mountainous.features.nix-builders names no builders on ${config.networking.hostName}; leave the feature off instead of enabling an empty matrix.";
      }
      {
        assertion = !(builtins.elem config.networking.hostName cfg.use);
        message = "${config.networking.hostName} cannot be its own remote builder; Nix would dispatch work to itself over SSH.";
      }
    ];

    nix = {
      distributedBuilds = true;
      buildMachines =
        map (
          name:
            {
              hostName = name;
              protocol = "ssh-ng";
            }
            // registry.${name}
        )
        cfg.use;

      settings = {
        # Without this a builder receives every dependency from this host. That is
        # the expensive direction: the link to Fuji loses ~3% of packets, which
        # holds a single TCP stream near 1.4 Mbit/s, while Fuji's own downlink is
        # two orders of magnitude faster. Let the builder fetch from the caches.
        builders-use-substitutes = true;
      };
    };
  };
}
