{
  description = "Nix config flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { nixpkgs, ... }: {
    nixosConfigurations = {
      ushiro = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";

        modules = [
          ./hardware/apple-m1.nix
          ./systems/ushiro.nix
          ./users/simonwjackson
        ];
      };

      unzen = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./hardware/intel.nix
          ./hardware/qemu.nix
          ./systems/unzen
        ];
      };
    };
  };
}
