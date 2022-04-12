{
  description = "Nix config flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { home-manager, nixpkgs, ... }:
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

        configuration = import ./users/simonwjackson/home.nix;
        homeDirectory = "/home/${username}";
        stateVersion = "22.05";
      };

      nixosConfigurations = {
        # nixos refers to the hostname
        fiji = lib.nixosSystem {
          inherit system;

          modules = [
            ./system/fiji.nix
          ];
        };
      };
    };
}
