{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  registry = import ./hosts.nix;
  others = builtins.filter (n: n != config.networking.hostName) (builtins.attrNames registry.builders);
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.nix-builders = {
    enable = mkEnableOption ''
      remote Nix builders from the fleet registry, so a build lands on a machine
      that can do it instead of needing --builders on the command line
    '';

    use = mkOption {
      type = types.listOf (types.enum (builtins.attrNames registry.builders));
      default = others;
      defaultText = "every builder in fleet.json except this host";
      description = "Builders from fleet.json that this host sends work to.";
    };

    sshKey = mkOption {
      type = types.str;
      default = "/etc/ssh/ssh_host_ed25519_key";
      description = ''
        This host's identity as a build client. Builders accept every host key
        in fleet.json's hostKeys, so no separate key needs to exist.
      '';
    };

    serve = mkEnableOption ''
      building for the rest of the fleet. Requires an entry for this host in
      fleet.json's builders. Every fleet host key may run `nix-daemon --stdio`
      as that entry's sshUser and nothing else; builds run at idle priority
      under the entry's MemoryHigh and MemoryMax
    '';
  };
}
