{lib, ...}: let
  inherit (lib) mkEnableOption;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.korri-cache = {
    enable = mkEnableOption ''
      Korri's signed Nix cache as a substituter.

      This is the consumer side only. Publishing belongs to Korri's own build,
      because only the project knows which closure a device installs; a
      machine-wide Nix hook would publish whatever else this machine builds. See
      nix/cache/README.md in Korri and `nix run .#korri-nix-cache-publish`
    '';
  };
}
