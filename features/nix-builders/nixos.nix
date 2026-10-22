{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  cfg = config.mountainous.features.nix-builders;
  registry = import ./hosts.nix;
  name = config.networking.hostName;
  me = registry.builders.${name} or null;
  used = lib.genAttrs cfg.use (n: registry.builders.${n});
  clientKeys =
    lib.attrValues (lib.filterAttrs (n: _: n != name) registry.hostKeys)
    ++ registry.legacyClientKeys;
in {
  config = mkMerge [
    (mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.use != [];
          message = "mountainous.features.nix-builders names no builders on ${name}; leave the feature off instead of enabling an empty matrix.";
        }
        {
          assertion = !(builtins.elem name cfg.use);
          message = "${name} cannot be its own remote builder; Nix would dispatch work to itself over SSH.";
        }
      ];

      nix = {
        distributedBuilds = true;
        buildMachines =
          lib.mapAttrsToList (n: b: {
            hostName = "nix-builder-${n}";
            protocol = "ssh-ng";
            inherit (b) sshUser maxJobs speedFactor;
            sshKey = cfg.sshKey;
            systems = [b.system];
            supportedFeatures = b.features;
          })
          used;

        settings = {
          # Without this a builder receives every dependency from this host. That is
          # the expensive direction: the link to Fuji loses ~3% of packets, which
          # holds a single TCP stream near 1.4 Mbit/s, while Fuji's own downlink is
          # two orders of magnitude faster. Let the builder fetch from the caches.
          builders-use-substitutes = true;
        };
      };

      # nix-daemon runs ssh as root and reads this file. The alias pins the
      # port and the host key; a builder that is down or refuses fails within
      # seconds, and Nix moves on to the next one.
      programs.ssh.extraConfig = lib.concatStrings (lib.mapAttrsToList (n: b: ''
          Host nix-builder-${n}
            HostName ${n}
            Port ${toString b.sshPort}
            HostKeyAlias nix-builder-${n}
            ConnectTimeout 5
            BatchMode yes
            ServerAliveInterval 30
        '')
        used);
      programs.ssh.knownHosts =
        lib.mapAttrs' (n: b: lib.nameValuePair "nix-builder-${n}" {publicKey = b.hostKey;}) used;
    })

    (mkIf cfg.serve {
      assertions = [
        {
          assertion = me != null;
          message = "mountainous.features.nix-builders.serve is on, but fleet.json has no builder named ${name}.";
        }
      ];
      # The name is read even when serve is off, so it must not fail on a
      # host without a registry entry.
      users.users.${
        (
          if me == null
          then {}
          else me
        ).sshUser or "simonwjackson"
      }.openssh.authorizedKeys.keys =
        map (key: ''restrict,command="${config.nix.package}/bin/nix-daemon --stdio" ${key}'') clientKeys;

      nix.settings.max-jobs = me.maxJobs;
      nix.settings.cores = lib.min 4 me.cpus;
      # The machine's own work comes first; builds take what is left.
      nix.daemonCPUSchedPolicy = "idle";
      nix.daemonIOSchedClass = "idle";
      mountainous.features.memory-guard.nixDaemon = {
        inherit (me) memoryHigh memoryMax;
      };
    })
  ];
}
