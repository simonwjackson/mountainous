{
  inputs = {
    tmesh.url = "github:simonwjackson/tmesh";
    myNeovim.url = "github:simonwjackson/neovim-nix-config";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mobile-nixos = {
      url = "github:NixOS/mobile-nixos";
      flake = false;
    };
  };

  outputs = inputs:
    inputs.snowfall-lib.mkFlake {
      inherit inputs;
      src = ./.;

      # Add modules to all NixOS systems.
      systems.modules.nixos = with inputs; [
        home-manager.nixosModules.home-manager
        myNeovim.nixosModules.default
        agenix.nixosModules.default
      ];

      homes.modules = with inputs; [
      ];

      systems.hosts.piney.modules = with inputs; [
        (import "${mobile-nixos}/lib/configuration.nix" {device = "pine64-pinephone";})
        (import "${mobile-nixos}/examples/phosh/phosh.nix")
      ];

      channels-config = {
        allowUnfree = true;

        permittedInsecurePackages = [
        ];

        # Additional configuration for specific packages.
        config = {
          # For example, enable smartcard support in Firefox.
          # firefox.smartcardSupport = true;
        };
      };

      snowfall = {
        namespace = "mountainous";

        meta = {
          name = "mountainous";
          title = "My System Configs";
        };
      };
    };
}
