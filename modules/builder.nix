# A remote Nix builder for the fleet.
#
# Zao's nix-daemon sends builds to every host with this layer over ssh-ng,
# and Nix spreads the derivations of one build across all of them.
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
      zaoBuilderKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAW4YRgdrxZjOPks6Jy8q4txJ4LZTVUFhNadApat21AG root@zao for remote builders";
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
          # The key may run the daemon and nothing else, so a stolen copy gives
          # a build slot, not a shell in a wheel account. Clients must use
          # ssh-ng://; the older ssh:// runs nix-store --serve and is refused.
          users.users.simon.openssh.authorizedKeys.keys = [
            "restrict,command=\"${config.nix.package}/bin/nix-daemon --stdio\" ${zaoBuilderKey}"
          ];

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
