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
          ./systems/ushiro
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

      yakushi = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./systems/yakushi
        ];
      };

      yari = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./hardware/intel.nix
          ./hardware/nvidia.nix
          ./systems/yari.nix
        ];
      };

      raiden = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./hardware/intel.nix
          ./hardware/nvidia.nix
          ./systems/raiden
        ];
      };
    };
  };
}
