{inputs}: let
  inherit (inputs) self nixpkgs;

  # Get all architectures from the systems directory
  architectures = builtins.attrNames (builtins.readDir ./systems);

  # Function to create a nixosSystem for a given architecture and system name
  mkNixosSystem = arch: name:
    nixpkgs.lib.nixosSystem {
      system = arch;
      modules = [
        ./systems/${arch}/${name}/default.nix
      ];
    };

  # Function to build system configurations for a specific architecture
  systemsForArch = arch: let
    systemNames = builtins.attrNames (builtins.readDir ./systems/${arch});
    systems = builtins.listToAttrs (map (name: {
        inherit name;
        value = mkNixosSystem arch name;
      })
      systemNames);
  in
    systems;

  # Combine all system configurations across all architectures
  allSystems =
    builtins.foldl' (
      acc: arch:
        acc // (systemsForArch arch)
    ) {}
    architectures;

  # Collect all VM builds for each architecture
  mkVmPackages = arch: let
    systemNames = builtins.attrNames (builtins.readDir ./systems/${arch});
    vmPkgs = builtins.listToAttrs (map (name: {
        name = "vm-${name}";
        value = self.nixosConfigurations.${name}.config.system.build.vm;
      })
      systemNames);
  in
    vmPkgs;
in {
  # Main flake utility function
  mkFlake = {inputs}: {
    nixosConfigurations = allSystems;

    # VM outputs for all configurations
    packages.x86_64-linux = mkVmPackages "x86_64-linux";
  };
}
