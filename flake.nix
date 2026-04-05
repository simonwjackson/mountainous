{
  nixConfig = {
    warn-dirty = false;
  };

  description = "Mountainous — unified NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-droid.url = "github:NixOS/nixpkgs/nixos-24.05";
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs-droid";
    };
    dnshack = {
      url = "github:ettom/dnshack";
      flake = false;
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    impermanence.url = "github:nix-community/impermanence";
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprdynamicmonitors = {
      url = "github:fiffeek/hyprdynamicmonitors";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flexget-webui = {
      url = "github:Flexget/webui";
      flake = false;
    };
    taskwarrior-recurrence = {
      url = "github:lyz-code/taskwarrior_recurrence";
      flake = false;
    };
    # Fuji-specific inputs
    tsnsrv = {
      url = "github:boinkor-net/tsnsrv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cascade = {
      url = "github:cascadefox/cascade";
      flake = false;
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-droid,
    nix-on-droid,
    disko,
    home-manager,
    agenix,
    nixos-hardware,
    impermanence,
    gomod2nix,
    hyprdynamicmonitors,
    nixos-anywhere,
    flexget-webui,
    taskwarrior-recurrence,
    tsnsrv,
    cascade,
    nixos-wsl,
    ...
  } @ inputs: let
    lib = nixpkgs.lib;
    systems = ["x86_64-linux" "aarch64-linux"];

    collectPackagePaths = prefix: dir: let
      entries = builtins.readDir dir;
      names = lib.sort (a: b: a < b) (builtins.attrNames entries);
    in
      lib.foldl' (
        acc: name: let
          type = entries.${name};
          path = dir + "/${name}";
          attrName =
            if prefix == ""
            then name
            else "${prefix}-${name}";
          current =
            lib.optionalAttrs
            (type == "directory" && builtins.pathExists (path + "/default.nix"))
            {"${attrName}" = path;};
          nested =
            if type == "directory"
            then collectPackagePaths attrName path
            else {};
        in
          acc // current // nested
      ) {}
      names;

    collectModulePaths = dir: let
      entries = builtins.readDir dir;
      names = lib.sort (a: b: a < b) (builtins.attrNames entries);
    in
      lib.concatMap (name: let
        type = entries.${name};
        path = dir + "/${name}";
      in
        if type != "directory"
        then []
        else
          lib.optional (builtins.pathExists (path + "/default.nix")) path
          ++ collectModulePaths path)
      names;

    collectPlatformModulePaths = dir: platformFile: let
      entries = builtins.readDir dir;
      names = lib.sort (a: b: a < b) (builtins.attrNames entries);
    in
      lib.concatMap (name: let
        type = entries.${name};
        path = dir + "/${name}";
        platformPath = path + "/${platformFile}";
        hasDefault = builtins.pathExists (path + "/default.nix");
        hasPlatform = type == "directory" && builtins.pathExists platformPath;
      in
        if hasPlatform
        then (lib.optional hasDefault path) ++ [platformPath]
        else if type == "directory"
        then collectPlatformModulePaths path platformFile
        else [])
      names;

    packagePaths = collectPackagePaths "" ./packages;
    nixosFeatureModulePaths = collectModulePaths ./features;
    nixosPresetModulePaths = collectModulePaths ./presets;
    droidFeatureModulePaths = collectPlatformModulePaths ./features "droid.nix";
    droidPresetModulePaths = collectPlatformModulePaths ./presets "droid.nix";

    packageOverlay = final: prev: let
      callPackage = lib.callPackageWith (final // {inherit inputs;});
      overlayPackagePaths = builtins.removeAttrs packagePaths ["scripts"];
    in
      lib.mapAttrs (_: path: callPackage path {}) overlayPackagePaths;

    extraOverlays = import ./overlays;
    projectOverlays = [packageOverlay] ++ extraOverlays;

    mkPkgs = system:
      import nixpkgs {
        inherit system;
        overlays = projectOverlays;
      };

    mkDroidPkgs = system:
      import nixpkgs-droid {
        inherit system;
        overlays = projectOverlays;
      };

    mkFlakePackages = system: let
      pkgs = mkPkgs system;
      callPackage = lib.callPackageWith (pkgs // {inherit inputs;});
      packageSet = lib.mapAttrs (_: path: callPackage path {}) packagePaths;
    in
      lib.filterAttrs (_: value: lib.isDerivation value) packageSet;

    mkHost = {
      system,
      hostPath,
      specialArgs ? {},
      extraModules ? [],
    }:
      let
        syncthingManifestPath = hostPath + "/syncthing.nix";
        syncthingManifest =
          if builtins.pathExists syncthingManifestPath
          then import syncthingManifestPath
          else null;
        # Host manifests are plain data. Keep the feature module as the schema
        # owner for runtime options by only forwarding option-shaped attrs here.
        hostAutoModules = lib.optional (syncthingManifest != null) {
          mountainous.features.syncthing = {
            enable = true;
          } // builtins.removeAttrs syncthingManifest ["deviceId"];
        };
      in
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit self cascade hyprdynamicmonitors tsnsrv; mountainousPlatform = "nixos";} // specialArgs;
        modules =
          [
            disko.nixosModules.default
            agenix.nixosModules.default
            home-manager.nixosModules.home-manager
          ]
          ++ nixosFeatureModulePaths
          ++ nixosPresetModulePaths
          ++ [
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
            }
            ({lib, ...}: {
              nix.settings = {
                experimental-features = ["nix-command" "flakes"];
                trusted-users = ["root" "@wheel" "simonwjackson" "admin"];
                warn-dirty = false;
              };
              users.users.simonwjackson.openssh.authorizedKeys.keyFiles = lib.mkDefault [
                ./secrets/keys/users/id_rsa.pub
                ./secrets/keys/users/id_ed25519.pub
              ];
              security.sudo.wheelNeedsPassword = lib.mkDefault false;
              networking.extraHosts = lib.mkDefault "127.0.0.1 amazesql01.database.windows.net";
              mountainous.features.tailscale.enable = lib.mkDefault true;
            })
            {nixpkgs.overlays = projectOverlays;}
          ]
          ++ hostAutoModules
          ++ [hostPath]
          ++ extraModules;
      };

    mkDroidHost = {
      system ? "aarch64-linux",
      hostPath,
      specialArgs ? {},
      extraModules ? [],
    }:
      let
        syncthingManifestPath = hostPath + "/syncthing.nix";
        syncthingManifest =
          if builtins.pathExists syncthingManifestPath
          then import syncthingManifestPath
          else null;
        hostAutoModules = lib.optional (syncthingManifest != null) {
          mountainous.features.syncthing = {
            enable = true;
          } // builtins.removeAttrs syncthingManifest ["deviceId"];
        };
      in
      nix-on-droid.lib.nixOnDroidConfiguration {
        pkgs = mkDroidPkgs system;
        extraSpecialArgs = {inherit self inputs; mountainousPlatform = "droid";} // specialArgs;
        modules =
          droidFeatureModulePaths
          ++ droidPresetModulePaths
          ++ hostAutoModules
          ++ [hostPath]
          ++ extraModules;
      };

    usuDroid = mkDroidHost {
      hostPath = ./hosts/usu;
    };
  in {
    overlays = {
      packages = packageOverlay;
      default = lib.composeManyExtensions projectOverlays;
    };

    packages = lib.genAttrs systems mkFlakePackages;

    nixosConfigurations = {
      fuji = mkHost {
        system = "aarch64-linux";
        hostPath = ./hosts/fuji;
      };
      yari = mkHost {
        system = "aarch64-linux";
        hostPath = ./hosts/yari;
      };
      rakku = mkHost {
        system = "x86_64-linux";
        hostPath = ./hosts/rakku;
        extraModules = [impermanence.nixosModules.default];
        specialArgs = {
          inherit gomod2nix;
        };
      };
      kita = mkHost {
        system = "x86_64-linux";
        hostPath = ./hosts/kita;
      };
      yuki = mkHost {
        system = "x86_64-linux";
        hostPath = ./hosts/yuki;
        specialArgs = {inherit nixos-hardware;};
      };
      aso = mkHost {
        system = "x86_64-linux";
        hostPath = ./hosts/aso;
        extraModules = [nixos-wsl.nixosModules.default];
      };
    };

    nixOnDroidConfigurations = {
      usu = usuDroid;
      default = usuDroid;
    };

    devShells = lib.genAttrs systems (system: let
      pkgs = mkPkgs system;
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          just
          gitleaks
        ];
      };
    });
  };
}
