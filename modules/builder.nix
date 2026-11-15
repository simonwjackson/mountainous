# Cache settings for a machine that builds for the fleet.
#
# Who may send builds, and how they are gated, is in build-federation.nix.
# This layer adds what a builder shares with Korri: its substituter and,
# where Korri trusts the key, signed outputs. It also keeps the builder's
# store as a cache: build results stay until the disk runs short.
{ config, self, ... }:
let
  hosts = config.nixos.hosts;
  gib = 1024 * 1024 * 1024;
in
{
  perSystem =
    { pkgs, lib, ... }:
    {
      checks.builder =
        let
          builders = lib.filterAttrs (_: host: lib.elem "builder" host.layers) hosts;
          check =
            name: _:
            let
              c = self.nixosConfigurations.${name}.config;
            in
            # A weekly time-based collection deleted every unrooted build
            # result each Monday, on disks that were 85 % free (fuji,
            # 2026-11-09: 7,590 paths). Collect only under disk pressure.
            assert !c.nix.gc.automatic;
            assert c.nix.settings.min-free == 20 * gib;
            assert c.nix.settings.max-free == 60 * gib;
            # Old system generations still lose their roots on a schedule,
            # so they cannot pin the store forever.
            assert c.systemd.services ? nix-prune-generations;
            assert c.systemd.timers.nix-prune-generations.timerConfig.OnCalendar == "weekly";
            name;
        in
        pkgs.runCommand "builder" { } ''
          echo ${lib.escapeShellArg (lib.concatStringsSep " " (lib.mapAttrsToList check builders))} > $out
        '';
    };

  nixos.modules.builder =
    {
      config,
      inputs,
      lib,
      ...
    }:
    let
      cfg = config.mountainous.builder;
    in
    {
      options.mountainous.builder.signingKey = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Sign every build with `nix-signing-key` from
          secrets/hosts/<host>.yaml. Korri's cache trusts only the keys it
          lists, so turn this on only for a host whose public key is there.
        '';
      };

      config = lib.mkMerge [
        {
          # Download what a Korri peer already built instead of building it
          # again. Korri owns the URL and the trusted keys.
          nix.settings.substituters = [ inputs.korri.cache.url ];
          nix.settings.trusted-public-keys = inputs.korri.cache.publicKeys;

          # The store is the builder's cache. The server layer's weekly
          # collection deletes every unrooted result, however new, so a
          # rebuild after Monday starts from nothing. Instead, Nix collects
          # while it builds, only when free space falls below min-free, and
          # stops once max-free is free again.
          nix.gc.automatic = false;
          nix.settings.min-free = 20 * gib;
          nix.settings.max-free = 60 * gib;

          # Without a scheduled collection, old system generations would
          # keep their store paths forever. Drop their roots after 14 days;
          # the space comes back at the next collection under pressure.
          systemd.services.nix-prune-generations = {
            description = "Delete system generations older than 14 days";
            serviceConfig.Type = "oneshot";
            script = ''
              ${config.nix.package}/bin/nix-env \
                --profile /nix/var/nix/profiles/system \
                --delete-generations 14d
            '';
          };
          systemd.timers.nix-prune-generations = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "weekly";
              Persistent = true;
            };
          };
        }
        (lib.mkIf cfg.signingKey {
          sops.secrets.nix-signing-key = {
            sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
            mode = "0400";
          };
          nix.settings.secret-key-files = [ config.sops.secrets.nix-signing-key.path ];
        })
      ];
    };
}
