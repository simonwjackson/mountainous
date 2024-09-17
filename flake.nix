{
  inputs = {
    nur.url = "github:nix-community/NUR";

    # elevate = {
    #   url = "github:simonwjackson/elevate";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    auto-cpufreq = {
      url = "github:AdnanHodzic/auto-cpufreq";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tmesh.url = "github:simonwjackson/tmesh";
    icho.url = "github:simonwjackson/icho";
    gamerack.url = "https://flakehub.com/f/simonwjackson/gamerack/*.tar.gz";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.4.1";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    suyu.url = "github:Noodlez1232/suyu-flake";
    nixpkgs-firefox-darwin.url = "github:bandithedoge/nixpkgs-firefox-darwin";
    disko.url = "github:nix-community/disko";

    simple-nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver/master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    backpacker = {
      url = "github:simonwjackson/backpacker";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    kmonad = {
      url = "git+https://github.com/kmonad/kmonad?submodules=1&dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Generate System Images
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-frost = {
      url = "github:snowfallorg/frost";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # INFO: https://github.com/snowfallorg/lib/issues/54#issuecomment-2067533982
    nixpkgs-mobile-nixos.url = "github:nixos/nixpkgs/0c56c244409eb4424611f37953bfd03c2534bcce";

    mobile-nixos = {
      url = "github:NixOS/mobile-nixos";
      flake = false;
    };

    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: let
    snowfallOutputs = inputs.snowfall-lib.mkFlake {
      inherit inputs;
      src = ./.;

      systems.modules.nixos =
        # Include all backpacker NixOS modules
        (builtins.attrValues inputs.backpacker.nixosModules)
        ++ [
          inputs.agenix.nixosModules.default
          inputs.disko.nixosModules.default
          inputs.home-manager.nixosModules.default
          inputs.kmonad.nixosModules.default
          inputs.icho.nixosModules.default
          inputs.nix-flatpak.nixosModules.nix-flatpak
          inputs.tmesh.nixosModules.default
          inputs.nur.nixosModules.nur
        ];

      systems.modules.darwin = with inputs; [
        home-manager.darwinModules.default
        icho.nixosModules.default
        tmesh.nixosModules.default
      ];

      systems.hosts.naka = {
        channelName = "nixpkgs-mobile-nixos";
      };

      homes.modules = with inputs; [
        backpacker.homeModules."desktops/hyprland"
        # elevate.homeModules.service
      ];

      overlays = with inputs; [
        snowfall-frost.overlays.default
        nur.overlay
      ];

      channels-config = {
        allowUnfree = true;
        # allowUnsupportedSystem = true;

        permittedInsecurePackages = [
        ];

        # Additional configuration for specific packages.
        config = {
          # For example, enable smartcard support in Firefox.
          # firefox.smartcardSupport = true;
        };
      };

      snowfall = {
        namespace = "mountainous";
        meta = {
          name = "mountainous";
          title = "My System Configs";
        };
      };
    };

    nixOnDroidOutputs.nixOnDroidConfigurations = let
      systemsDir = ./systems/aarch64-droid;
      systemFiles = builtins.attrNames (builtins.readDir systemsDir);
      systemNames = map (file: builtins.head (builtins.split "\\." file)) systemFiles;

      homeManagerDroid = {
        home-manager = {
          backupFileExtension = "hm-bak";
          useGlobalPkgs = true;
          config = {
            config,
            lib,
            pkgs,
            ...
          }: {
            imports = (
              let
                # Function to find default.nix files, stopping at each found default.nix
                findDefaultNix = dir: let
                  contents = builtins.readDir dir;
                  hasDefaultNix = builtins.hasAttr "default.nix" contents && contents."default.nix" == "regular";
                in
                  if hasDefaultNix
                  then [(dir + "/default.nix")]
                  else let
                    subdirs = lib.filterAttrs (n: v: v == "directory") contents;
                    subdirPaths = map (n: dir + "/${n}") (builtins.attrNames subdirs);
                  in
                    lib.concatMap findDefaultNix subdirPaths;
              in
                findDefaultNix ./modules/home
            );
          };
        };
      };

      mkConfig = name:
        inputs.nix-on-droid.lib.nixOnDroidConfiguration {
          pkgs = import inputs.nixpkgs {system = "aarch64-linux";};
          modules = [
            (systemsDir + "/${name}")
            homeManagerDroid
            {
              home-manager.config = import (./homes/aarch64-droid + "/nix-on-droid@${name}");
            }
          ];
        };
    in
      builtins.listToAttrs (
        map
        (name: {
          inherit name;
          value = mkConfig name;
        })
        systemNames
      );
  in
    snowfallOutputs // nixOnDroidOutputs;
}
