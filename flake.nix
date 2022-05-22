{
  description = "Nix config flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { home-manager, nixpkgs, nixos-hardware, ... }:
    let
      system = "x86_64-linux";
      #system = "aarch64-linux";

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
        inherit pkgs username system;
        # system = "aarch64-linux";

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

        # adama = lib.nixosSystem {
        #  # system = "aarch64-linux";

        #   modules = [
        #     ./system/adama.nix
        #   ];
        # };

        nixos = lib.nixosSystem {
          inherit system;

          modules = [
            ./system/nixos.nix
          ];
        };
      };
    };
}
