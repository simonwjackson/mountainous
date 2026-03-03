{
  description = "Mountainous — unified NixOS configurations";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
    impermanence.url = "github:nix-community/impermanence";
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Fuji-specific inputs
    pyxis.url = "github:simonwjackson/pyxis";
    tsnsrv = {
      url = "github:boinkor-net/tsnsrv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, disko, home-manager, agenix, impermanence, gomod2nix, pyxis, tsnsrv, ... }:
  let
    mkHost = { system, hostPath, specialArgs ? {}, extraModules ? [] }: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit self; } // specialArgs;
      modules = [
        disko.nixosModules.default
        agenix.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
        { nixpkgs.overlays = import ./overlays; }
        hostPath
      ] ++ extraModules;
    };
  in {
    nixosConfigurations = {
      fuji = mkHost {
        system = "aarch64-linux";
        hostPath = ./hosts/fuji;
        specialArgs = { inherit pyxis tsnsrv; };
      };
      yari = mkHost {
        system = "aarch64-linux";
        hostPath = ./hosts/yari;
      };
      rakku = mkHost {
        system = "x86_64-linux";
        hostPath = ./hosts/rakku;
        extraModules = [ impermanence.nixosModules.default ];
        specialArgs = {
          inherit gomod2nix;
        };
      };
      kita = mkHost {
        system = "x86_64-linux";
        hostPath = ./hosts/kita;
        extraModules = [ impermanence.nixosModules.default ];
        specialArgs = { inherit pyxis; };
      };
    };
    devShells = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [ ];
        };
      });
  };
}
