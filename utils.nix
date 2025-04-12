{inputs}: let
  inherit (inputs) self nixpkgs impermanence disko home-manager;

  # Path to default home-manager configuration
  defaultHomePath = ./nix/home/default.nix;

  # Check if a file exists
  fileExists = path: builtins.pathExists path;

  # Function to recursively collect module paths from a directory
  collectModules = dir:
    if !(builtins.pathExists dir)
    then []
    else let
      # Recursive function to find all module directories
      findModuleDirs = path: let
        dirContent = builtins.readDir path;
        dirNames = builtins.attrNames dirContent;

        # Get all subdirectories
        subDirs =
          map (name: path + "/${name}")
          (builtins.filter (name: dirContent.${name} == "directory") dirNames);

        # Check if this is a module directory (has default.nix)
        isModuleDir = builtins.pathExists (path + "/default.nix");

        # Recursively search subdirectories
        subDirModules = builtins.concatLists (map findModuleDirs subDirs);
      in
        # Include current directory if it's a module dir, plus all subdirectories
        (
          if isModuleDir
          then [path]
          else []
        )
        ++ subDirModules;

      # Find all module directories
      modulePaths = findModuleDirs dir;
    in
      map (path: path + "/default.nix") modulePaths;

  # Collect all home-manager modules
  homeManagerModules = collectModules ./nix/modules/home;

  # Collect all NixOS modules
  nixosModules = collectModules ./nix/modules/nixos;

  # Get all architectures from the systems directory
  architectures = builtins.attrNames (builtins.readDir ./nix/systems);

  # Function to create a home-manager module for a given architecture and system name
  mkHomeManagerModule = arch: name: {
    # Include home-manager module

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;

    # Pass inputs to home-manager modules as specialArgs
    home-manager.extraSpecialArgs = {inherit inputs;};

    # Apply the default home configuration if it exists
    home-manager.users.simonwjackson = {
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
          if fileExists ./nix/systems/${arch}/${name}/home.nix
          then [./nix/systems/${arch}/${name}/home.nix]
          else []
        );
    };
  };

  # Function to create a nixosSystem for a given architecture and system name
  mkNixosSystem = overlays: arch: name:
    nixpkgs.lib.nixosSystem {
      system = arch;
      # Pass inputs as specialArgs to make them available to all modules
      specialArgs = {inherit inputs;};
      modules =
        # First import all NixOS modules
        nixosModules
        ++ [
          # Add our packages overlay to make custom packages available
          {nixpkgs.overlays = [(final: prev: collectPackages prev arch)] ++ overlays;}
          # System configuration
          ./nix/systems/${arch}/${name}/default.nix
          # impermanence module
          impermanence.nixosModules.impermanence
          # disko module
          disko.nixosModules.default
          # Add home-manager as a module
          home-manager.nixosModules.home-manager
          # Include our home-manager configuration
          (mkHomeManagerModule arch name)
        ];
    };

  # Function to build system configurations for a specific architecture
  systemsForArch = overlays: arch: let
    systemNames = builtins.attrNames (builtins.readDir ./nix/systems/${arch});
    systems = builtins.listToAttrs (map (name: {
        inherit name;
        value = mkNixosSystem overlays arch name;
      })
      systemNames);
  in
    systems;

  # Combine all system configurations across all architectures
  allSystems = overlays:
    builtins.foldl' (
      acc: arch:
        acc // (systemsForArch overlays arch)
    ) {}
    architectures;

  # Collect all VM builds for each architecture
  mkVmPackages = arch: let
    systemNames = builtins.attrNames (builtins.readDir ./nix/systems/${arch});
    vmPkgs = builtins.listToAttrs (map (name: {
        name = "vm-${name}";
        value = self.nixosConfigurations.${name}.config.system.build.vm;
      })
      systemNames);
  in
    vmPkgs;
  # Function to recursively collect and import packages from the packages directory
  collectPackages = pkgs: system: let
    # Check if packages directory exists
    packagesDir = ./nix/packages;
    packagesDirExists = builtins.pathExists packagesDir;

    # Function to recursively find all package directories
    # A package directory is one containing either default.nix or a file with same name as dir
    findPackageDirs = path:
      if !(builtins.pathExists path)
      then []
      else let
        dirContent = builtins.readDir path;
        dirNames = builtins.attrNames dirContent;
        baseName = baseNameOf path;

        # Check if this is a valid package directory (has default.nix or self-named .nix)
        isPackageDir =
          builtins.pathExists (path + "/default.nix")
          || builtins.pathExists (path + "/${baseName}.nix");

        # Get all subdirectories
        subDirs =
          map (name: path + "/${name}")
          (builtins.filter (name: dirContent.${name} == "directory") dirNames);

        # Recursively search subdirectories
        subDirPackages = builtins.concatLists (map findPackageDirs subDirs);
      in
        # Include current directory if it's a package dir, plus all subdirectories
        (
          if isPackageDir
          then [path]
          else []
        )
        ++ subDirPackages;

    # Find all package directories
    packageDirs =
      if packagesDirExists
      then findPackageDirs packagesDir
      else [];

    # Function to convert a package path to a name
    pathToName = path: let
      # Start from the packages dir to get the relative path
      relPath =
        builtins.substring (builtins.stringLength (toString packagesDir) + 1)
        (builtins.stringLength (toString path)) (toString path);
      # Replace slashes with dashes for the package name
      name = builtins.replaceStrings ["/"] ["-"] relPath;
    in
      name;

    # Import each package and create an attribute set
    packageSet = builtins.listToAttrs (map (path: {
        name = pathToName path;
        value =
          if builtins.pathExists (path + "/default.nix")
          then pkgs.callPackage (path + "/default.nix") {inherit inputs;}
          else pkgs.callPackage (path + "/${baseNameOf path}.nix") {inherit inputs;};
      })
      packageDirs);
  in
    packageSet;
in {
  # Main flake utility function
  mkFlake = {
    inputs,
    namespace,
    overlays ? [],
  }: let
    # Create system configurations with overlays
    systems = allSystems overlays;
    # Create package sets for each system
    pkgSets = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"] (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = overlays;
        };
        packages = collectPackages pkgs system;
      in
        # Merge VM packages with our custom packages
        (
          if system == "x86_64-linux"
          then mkVmPackages "x86_64-linux"
          else {}
        )
        // packages
    );
  in {
    nixosConfigurations = systems;

    # Packages output for each supported system
    packages = pkgSets;

    # Make packages available to dependent flakes
    overlay = final: prev: collectPackages prev prev.system;
  };
}
