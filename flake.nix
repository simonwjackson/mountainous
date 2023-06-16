{
  description = "Nix config flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { nixpkgs, ... }: {
    nixosConfigurations = {
      # Dual XEON Server
      unzen = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./hardware/intel.nix
          ./hardware/qemu.nix
          ./systems/unzen
        ];
      };

      # XPS 17 (headless)
      zao = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [ ./systems/zao ];
      };

      # Lenovo i9 dual
      fiji = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [ ./systems/fiji ];
      };

      # Lenovo desktop
      kita = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [ ./systems/kita ];
      };
    };
  };
}
