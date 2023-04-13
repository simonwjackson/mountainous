{
  description = "Nix config flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    # home-manager.url = "github:nix-community/home-manager";
    # home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { nixpkgs, nixos-hardware, ... }:
    let
      #   # system = "x86_64-linux";
      #
      #   pkgs = import nixpkgs {
      #     inherit system;
      #
      #     config = {
      #       allowUnfree = true;
      #     };
      #   };
      #
      #   lib = nixpkgs.lib;
      username = "simonwjackson";
      #
    in
    {
      # homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
      #   #inherit pkgs username system;
      #   # system = "aarch64-linux";
      #   pkgs = nixpkgs.legacyPackages.${system};
      #   modules = [
      #     ./users/${username}
      #     {
      #       home = {
      #         homeDirectory = "/home/${username}";
      #         stateVersion = "22.05";
      #       };
      #     }
      #   ];
      # };

      nixosConfigurations = {
        # fiji = lib.nixosSystem {
        #   inherit system;
        #
        #   modules = [
        #     ./system/fiji.nix
        #     nixos-hardware.nixosModules.dell-xps-13-9310
        #   ];
        # };
        #
        ushiro = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";

          modules = [
            ./system/ushiro.nix
            ./users/simonwjackson # home-manager.nixosModules.home-manager
            # {
            #   home-manager.useGlobalPkgs = true;
            #   home-manager.useUserPackages = true;
            #   home-manager.users.${username} = import ./users/${username};
            #
            #   home.homeDirectory = "/home/${username}";
            #   home.stateVersion = "23.05";
            #
            #   # Optionally, use home-manager.extraSpecialArgs to pass
            #   # arguments to home.nix
            # }
          ];
        };
      };
    };
}
