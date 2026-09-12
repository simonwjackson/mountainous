{lib, ...}: let
  inherit (lib) mkEnableOption mkOption types;
  registry = import ./hosts.nix;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.nix-builders = {
    enable = mkEnableOption ''
      remote Nix builders, so a build lands on a machine that can do it natively
      instead of needing --builders on the command line
    '';

    use = mkOption {
      type = types.listOf (types.enum (builtins.attrNames registry));
      default = [];
      description = ''
        Builders from ./hosts.nix that this host can reach. Reachability is not
        declared there because it depends on this host's root SSH key being
        accepted by the builder.
      '';
      example = ["fuji"];
    };
  };
}
