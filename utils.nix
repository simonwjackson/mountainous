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
      # Pass inputs as specialArgs to make them available to all modules
      specialArgs = { inherit inputs; };
      modules = 
        # First import all NixOS modules
        nixosModules
        ++ [
          # Add our packages overlay to make custom packages available
          { nixpkgs.overlays = [ (final: prev: collectPackages prev arch) ]; }
          # System configuration
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
  # Function to collect and import packages from the packages directory
  collectPackages = pkgs: system: let
    # Check if packages directory exists
    packagesDir = ./packages;
    packagesDirExists = builtins.pathExists packagesDir;
    
    # Get package names (directory names) from packages directory
    packageNames = if packagesDirExists 
      then builtins.attrNames (builtins.readDir packagesDir)
      else [];
      
    # Import each package and create an attribute set
    packageSet = builtins.listToAttrs (map (name: {
      inherit name;
      value = pkgs.callPackage (packagesDir + "/${name}") {};
    }) packageNames);
  in
    packageSet;

in {
  # Main flake utility function
  mkFlake = {inputs, namespace}: let
    # Create package sets for each system
    pkgSets = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"] (system:
      let 
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [];
        };
        packages = collectPackages pkgs system;
      in
        # Merge VM packages with our custom packages
        (if system == "x86_64-linux" then mkVmPackages "x86_64-linux" else {}) // packages
    );
  in {
    nixosConfigurations = allSystems;

    # Packages output for each supported system
    packages = pkgSets;

    # Make packages available to dependent flakes
    overlay = final: prev: collectPackages prev prev.system;
  };
}
