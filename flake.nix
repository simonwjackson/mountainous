{
  description = "Nix config flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { nixpkgs, ... }: {
    nixosConfigurations = {
      # Home Server
      unzen = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [ ./systems/unzen ];
      };

      # Gaming
      zao = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [ ./systems/zao ];
      };

      # Laptop
      fiji = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [ ./systems/fiji ];
      };
    };
  };
}
