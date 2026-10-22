# Cache settings for a machine that builds for the fleet.
#
# Who may send builds, and how they are gated, is in build-federation.nix.
# This layer adds what a builder shares with Korri: its substituter and,
# where Korri trusts the key, signed outputs.
{
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
