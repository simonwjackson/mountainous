{
  description = "My NixOS configuration";

  inputs = {
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    vscode-server.url = "github:nix-community/nixos-vscode-server";

    # Nixpkgs
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-23.05";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    agenix.url = "github:ryantm/agenix";
    hardware.url = "github:nixos/nixos-hardware";
    nix-colors.url = "github:misterio77/nix-colors";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager/master";
    };

    hyprland = {
      url = "github:hyprwm/hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprwm-contrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { agenix, self, nixpkgs, home-manager, hardware, nix-darwin, nix-on-droid, ... }@inputs:
    let
      inherit (self) outputs;
      lib = nixpkgs.lib // home-manager.lib;
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forEachSystem = f: lib.genAttrs systems (system: f pkgsFor.${system});
      pkgsFor = lib.genAttrs systems (system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      });
      rootPath = ./.;
    in
    {
      inherit lib;

      # Reusable nixos modules you might want to export
      # These are usually stuff you would upstream into nixpkgs
      nixosModules = import ./nixos/modules;

      # Reusable home-manager modules you might want to export
      # These are usually stuff you would upstream into home-manager
      homeManagerModules = import ./home-manager/modules;

      # Your custom packages and modifications, exported as overlays
      overlays = import ./nix/overlays { inherit inputs outputs; };

      # Your custom packages
      # Acessible through 'nix build', 'nix shell', etc
      packages = forEachSystem (pkgs: import ./nix/pkgs { inherit pkgs; });

      devShells = forEachSystem (pkgs: import ./shell.nix { inherit pkgs; });

      # Formatter for your nix files, available through 'nix fmt'
      # Other options beside 'alejandra' include 'nixpkgs-fmt'
      formatter = forEachSystem (pkgs: pkgs.nixpkgs-fmt);

      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild <action> --flake .#your-hostname'
      nixosConfigurations = {
        # Main desktop
        fiji = lib.nixosSystem {
          modules = [
            ./nixos/hosts/fiji
            agenix.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager.users.simonwjackson = import ./home-manager/users/simonwjackson/hosts/fiji;
              home-manager.extraSpecialArgs = { inherit inputs outputs rootPath self; };
            }
          ];
          specialArgs = { inherit inputs outputs rootPath self; };
        };

        # Remote Server
        yabashi = lib.nixosSystem {
          modules = [
            ./nixos/hosts/yabashi
            agenix.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager.users.simonwjackson = import ./home-manager/users/simonwjackson/hosts/yabashi;
              home-manager.extraSpecialArgs = { inherit inputs outputs rootPath self; };
            }
          ];
          specialArgs = { inherit inputs outputs rootPath self; };
        };

        # Home Server
        unzen = lib.nixosSystem {
          modules = [
            ./nixos/hosts/unzen
            agenix.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager.users.simonwjackson = import ./home-manager/users/simonwjackson/hosts/unzen;
              home-manager.extraSpecialArgs = { inherit inputs outputs rootPath self; };
            }
          ];
          specialArgs = { inherit inputs outputs rootPath self; };
        };

        # router
        rakku = lib.nixosSystem {
          modules = [
            ./nixos/hosts/rakku
            agenix.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager.users.simonwjackson = import ./home-manager/users/simonwjackson/hosts/rakku;
              home-manager.extraSpecialArgs = { inherit inputs outputs rootPath self; };
            }
          ];
          specialArgs = { inherit inputs outputs rootPath self; };
        };

        # portable gaming rig
        zao = lib.nixosSystem {
          modules = [
            ./nixos/hosts/zao
            agenix.nixosModules.default
            hardware.nixosModules.dell-xps-17-9700-nvidia
            home-manager.nixosModules.home-manager
            {
              home-manager.users.simonwjackson = import ./home-manager/users/simonwjackson/hosts/zao;
              home-manager.extraSpecialArgs = { inherit inputs outputs rootPath self; };
            }
          ];
          specialArgs = { inherit inputs outputs rootPath self; };
        };
      };

      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#ushiro
      darwinConfigurations."ushiro" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit inputs outputs rootPath self; };
        modules = [
          ./nix-darwin/hosts/ushiro
          agenix.nixosModules.default
          home-manager.darwinModules.home-manager
          {
            home-manager.extraSpecialArgs = { inherit inputs outputs rootPath self; };
            home-manager.users.sjackson217 = import ./home-manager/users/simonwjackson/hosts/ushiro;
          }
        ];
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."ushiro".pkgs;

      nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
        extraSpecialArgs = { inherit inputs outputs rootPath self; };
        modules = [
          ./nix-on-droid/hosts/usu
          {
            home-manager = {
              # backupFileExtension = "hm-bak";
              # useGlobalPkgs = true;
              # extraSpecialArgs = { inherit inputs outputs rootPath self; };

              config =
                { config, lib, pkgs, ... }:
                {
                  # Read the changelog before changing this value
                  home.stateVersion = "23.05";
                  home = {
                    username = "nix-on-droid";
                    homeDirectory = "/data/data/com.termux.nix/files/home";
                    packages = with pkgs; [
                      jq
                    ];
                  };
                  # insert home-manager config
                };
            };
          }
          # home-manager.darwinModules.home-manager
          # {
          #   home-manager.extraSpecialArgs = { inherit inputs outputs rootPath self; };
          #   home-manager.users.nix-on-droid = import ./home-manager/users/simonwjackson/hosts/usu;
          # }
        ];
      };

      # Standalone home-manager configuration entrypoint
      # Available through 'home-manager <action> --flake .#simonwjackson'
      # homeConfigurations = {
      #   # Desktops
      #   "simonwjackson@fiji" = lib.homeManagerConfiguration {
      #     modules = [
      #       ./home-manager/users/simonwjackson/hosts/fiji
      #       agenix.homeManagerModules.age
      #     ];
      #     pkgs = pkgsFor.x86_64-linux // outputs.packages;
      #     extraSpecialArgs = { inherit inputs outputs; };
      #   };
      # };
    };
}
