{
  inputs = {
    tmesh.url = "github:simonwjackson/tmesh";
    myNeovim.url = "github:simonwjackson/neovim-nix-config";
    gamerack.url = "https://flakehub.com/f/simonwjackson/gamerack/*.tar.gz";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.4.1";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    suyu.url = "github:Noodlez1232/suyu-flake";
    simple-nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver/nixos-23.11";

    # Generate System Images
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    agenix = {
      # HACK: https://github.com/ryantm/agenix/issues/248
      url = "github:ryantm/agenix?ref=0.15.0";
      # url = "github:ryantm/agenix";
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

    snowfall-frost = {
      url = "github:snowfallorg/frost";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mobile-nixos = {
      url = "github:NixOS/mobile-nixos";
      flake = false;
    };

    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
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
        nix-flatpak.nixosModules.nix-flatpak
        simple-nixos-mailserver.nixosModule
      ];

      systems.modules.darwin = with inputs; [
        home-manager.darwinModules.home-manager
        myNeovim.nixosModules.default
        tmesh.nixosModules.aarch64-darwin.default
      ];

      homes.modules = with inputs; [
      ];

      # HACK: tmesh needs a better default
      systems.hosts.fiji.modules = with inputs; [
        tmesh.nixosModules.x86_64-linux.default
      ];

      systems.hosts.yari.modules = with inputs; [
        tmesh.nixosModules.x86_64-linux.default
      ];

      systems.hosts.zao.modules = with inputs; [
        tmesh.nixosModules.x86_64-linux.default
      ];

      systems.hosts.unzen.modules = with inputs; [
        tmesh.nixosModules.x86_64-linux.default
        gamerack.nixosModules.x86_64-linux.default
      ];

      systems.hosts.kita.modules = with inputs; [
        tmesh.nixosModules.x86_64-linux.default
      ];

      systems.hosts.rakku.modules = with inputs; [
        tmesh.nixosModules.x86_64-linux.default
      ];
      # HACK: END

      systems.hosts.piney.modules = [
        (import "${inputs.mobile-nixos}/lib/configuration.nix" {device = "pine64-pinephone";})
        (import "${inputs.mobile-nixos}/examples/phosh/phosh.nix")
      ];

      overlays = with inputs; [
        snowfall-frost.overlays.default
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
