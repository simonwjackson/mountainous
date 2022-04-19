{
  description = "Nix config flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { home-manager, nixpkgs, nixos-hardware, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;

        config = {
          allowUnfree = true;
        };
      };

      lib = nixpkgs.lib;
      username = "simonwjackson";

    in
    {
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit system pkgs username;

        configuration = import ./users/${username};
        homeDirectory = "/home/${username}";
        stateVersion = "22.05";
      };

      nixosConfigurations = {
        fiji = lib.nixosSystem {
          inherit system;

          modules = [
            ./system/fiji.nix
            nixos-hardware.nixosModules.microsoft-surface
          ];
        };

        nixos = lib.nixosSystem {
          inherit system;

          modules = [
            ./system/nixos.nix
          ];
        };
      };
    };
}
