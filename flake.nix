{
  description = "My NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: {
    nixosConfigurations = {
      # First system configuration
      system1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration-system1.nix
        ];
      };

      # Second system configuration
      system2 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration-system2.nix
        ];
      };
    };

    # VM outputs for both configurations
    packages.x86_64-linux = {
      vm-system1 = self.nixosConfigurations.system1.config.system.build.vm;
      vm-system2 = self.nixosConfigurations.system2.config.system.build.vm;
    };
  };
}