{inputs}: let
  inherit (inputs) self nixpkgs home-manager;

  # Path to default home-manager configuration
  defaultHomePath = ./home/default.nix;

  # Check if a file exists
  fileExists = path: builtins.pathExists path;
  
  # Function to collect module paths from a directory
  collectModules = dir: 
    if !(builtins.pathExists dir) then []
    else
      let
        dirContent = builtins.readDir dir;
        dirNames = builtins.attrNames dirContent;
        dirPaths = map (name: dir + "/${name}") 
          (builtins.filter (name: dirContent.${name} == "directory") dirNames);
        modulePaths = builtins.filter 
          (path: builtins.pathExists (path + "/default.nix")) 
          dirPaths;
      in
        map (path: path + "/default.nix") modulePaths;
        
  # Collect all home-manager modules
  homeManagerModules = collectModules ./modules/home;
  
  # Collect all NixOS modules
  nixosModules = collectModules ./modules/nixos;

  # Get all architectures from the systems directory
  architectures = builtins.attrNames (builtins.readDir ./systems);

  # Function to create a home-manager module for a given architecture and system name
  mkHomeManagerModule = arch: name: {
    # Include home-manager module

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;

    # Apply the default home configuration if it exists
    home-manager.users.nixos = {
      config,
      pkgs,
      ...
    }: {
      imports =
        # First import all home-manager modules
        homeManagerModules
        ++
        # Then import the default configuration if it exists
        (
          if fileExists defaultHomePath
          then [defaultHomePath]
          else []
        )
        ++
        # Then import system-specific configuration if it exists to override defaults
        (
          if fileExists ./systems/${arch}/${name}/home.nix
          then [./systems/${arch}/${name}/home.nix]
          else []
        );
    };
  };

  # Function to create a nixosSystem for a given architecture and system name
  mkNixosSystem = arch: name:
    nixpkgs.lib.nixosSystem {
      system = arch;
      modules = 
        # First import all NixOS modules
        nixosModules
        ++ [
          ./systems/${arch}/${name}/default.nix
          # Add home-manager as a module
          home-manager.nixosModules.home-manager
          # Include our home-manager configuration
          (mkHomeManagerModule arch name)
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
