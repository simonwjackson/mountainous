{
  description = "My NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: let
    utils = import ./utils.nix {inherit inputs;};
  in
    utils.mkFlake {
      inherit inputs;
    };
}
