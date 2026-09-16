# The only file that knows how a host becomes a nixosConfiguration.
#
# Every other module in this tree writes to `nixos.modules.<layer>` or
# declares a host under `nixos.hosts.<name>`. Nothing else imports nixpkgs.
{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.nixos = {
    modules = mkOption {
      type = types.lazyAttrsOf types.deferredModule;
      default = { };
      description = ''
        Named NixOS module layers. Many files may assign to the same layer.
        The module system merges them, so a layer is the sum of every file
        that mentions it.
      '';
    };

    hosts = mkOption {
      default = { };
      type = types.lazyAttrsOf (
        types.submodule {
          options = {
            system = mkOption {
              type = types.str;
              default = "x86_64-linux";
            };

            layers = mkOption {
              type = types.listOf types.str;
              default = [ "base" ];
              description = "Names from `nixos.modules` that this host imports.";
            };

            module = mkOption {
              type = types.deferredModule;
              default = { };
              description = "Configuration unique to this one machine.";
            };
          };
        }
      );
    };
  };

  config = {
    systems = lib.unique (lib.mapAttrsToList (_: host: host.system) config.nixos.hosts);

    flake.nixosConfigurations = lib.mapAttrs (
      hostName: host:
      inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          {
            networking.hostName = hostName;
            nixpkgs.hostPlatform = host.system;
          }
          host.module
        ] ++ map (layer: config.nixos.modules.${layer}) host.layers;
      }
    ) config.nixos.hosts;
  };
}
