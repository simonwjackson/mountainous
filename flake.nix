{
  description = "NixOS config flake";

  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      inherit (self) outputs;
      # Supported systems for your flake packages, shell, etc.
      systems =
        [ "aarch64-linux" "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
      # This is a function that generates an attribute by calling a function you
      # pass to it, with each system as an argument
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      formatter =
        forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

      nixosConfigurations = let
        hosts = [ "unzen" "zao" "fiji" ];
        generateConfig = host:
          nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs outputs; };
            modules = [ ./hosts/${host} ];
          };
      in builtins.listToAttrs (map (host: {
        name = host;
        value = generateConfig host;
      }) hosts);
    };
}
