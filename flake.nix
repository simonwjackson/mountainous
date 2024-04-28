{
  inputs = {
    tmesh.url = "github:simonwjackson/tmesh";
    myNeovim.url = "github:simonwjackson/neovim-nix-config";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mobile-nixos = {
      # url = "github:matthewcroughan/mobile-nixos";
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
        inputs.myNeovim.nixosModules.default
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
        # Choose a namespace to use for your flake's packages, library,
        # and overlays.
        namespace = "mountainous";

        # Add flake metadata that can be processed by tools like Snowfall Frost.
        meta = {
          # A slug to use in documentation when displaying things like file paths.
          name = "mountainous";

          # A title to show for your flake, typically the name.
          title = "My System Configs";
        };
      };
    };
}
