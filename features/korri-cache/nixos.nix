{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  cfg = config.mountainous.features.korri-cache;

  # Korri owns these facts. Reading them keeps revocation to one edit in
  # nix/cache/identity.nix there, and keeps this repository from holding a
  # second list of keys that a revoked builder would still be trusted by.
  korri = inputs.korri-cache;
  cache = korri.cache;

  # Both scripts come from the same pinned Korri source as the keys, so the
  # publisher and the trust list can never describe different caches. They are
  # run as plain scripts rather than through Korri's flake apps: that keeps
  # Korri's nixpkgs out of this host's evaluation, and the only cost is naming
  # their runtime tools here.
  postBuildHook = pkgs.writeShellApplication {
    name = "korri-cache-post-build-hook";
    runtimeInputs = [
      config.nix.package
      pkgs.coreutils
    ];
    text = ''
      export KORRI_CACHE_SECRET_KEY=${lib.escapeShellArg (toString cfg.publish.signingKeyFile)}
      export KORRI_CACHE_STAGING=${lib.escapeShellArg cfg.publish.stagingDir}
      exec bash ${korri}/nix/cache/post-build-hook.sh
    '';
  };
in {
  config = mkIf cfg.enable (mkMerge [
    {
      nix.settings = {
        substituters = [cache.url];
        trusted-public-keys = cache.publicKeys;
      };
    }

    (mkIf cfg.publish.enable {
      assertions = [
        {
          assertion = cfg.publish.signingKeyFile != null;
          message = "mountainous.features.korri-cache.publish needs signingKeyFile; an unsigned path is refused by every consumer.";
        }
        {
          assertion = cfg.publish.githubTokenFile != null;
          message = "mountainous.features.korri-cache.publish needs githubTokenFile; the upload timer has no interactive gh login.";
        }
      ];

      # Every local build signs itself into the staging cache. This must stay
      # cheap and must never fail a build, so it only writes to a local file
      # cache; the network half runs on the timer below.
      nix.settings.post-build-hook = "${postBuildHook}/bin/korri-cache-post-build-hook";

      systemd.tmpfiles.rules = [
        "d ${cfg.publish.stagingDir} 0700 root root -"
      ];

      systemd.services.korri-nix-cache-upload = {
        description = "Publish this machine's Korri builds to the signed cache";
        # Uploading during boot competes with whatever the machine is here to
        # do, and a batch is never urgent.
        after = ["network-online.target"];
        wants = ["network-online.target"];
        path = [
          config.nix.package
          pkgs.bash
          pkgs.coreutils
          pkgs.gh
          pkgs.git
          pkgs.gnused
          pkgs.jq
          pkgs.python3
        ];
        environment = {
          KORRI_ROOT = "${korri}";
          KORRI_CACHE_STAGING = cfg.publish.stagingDir;
          # nix and gh both want a home for their caches and config.
          HOME = "/root";
        };
        serviceConfig =
          {
            Type = "oneshot";
          }
          # gh reads GH_TOKEN from the environment. A token written into a unit
          # file would be world-readable in the Nix store.
          // lib.optionalAttrs (cfg.publish.githubTokenFile != null) {
            EnvironmentFile = cfg.publish.githubTokenFile;
          };
        script = ''
          exec bash ${korri}/nix/cache/upload-staged.sh
        '';
      };

      systemd.timers.korri-nix-cache-upload = {
        description = "Korri cache upload timer";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = cfg.publish.schedule;
          # A builder that was asleep at the scheduled minute still publishes.
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
      };
    })
  ]);
}
