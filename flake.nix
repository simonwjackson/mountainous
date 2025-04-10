{
  description = "My NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs: let
    utils = import ./utils.nix {inherit inputs;};
  in
    utils.mkFlake {
      inherit inputs;
    };
}

