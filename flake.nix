{
  inputs = {
    tmesh.url = "github:simonwjackson/tmesh";
    icho.url = "github:simonwjackson/icho";
    gamerack.url = "https://flakehub.com/f/simonwjackson/gamerack/*.tar.gz";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.4.1";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    suyu.url = "github:Noodlez1232/suyu-flake";
    nixpkgs-firefox-darwin.url = "github:bandithedoge/nixpkgs-firefox-darwin";
    disko.url = "github:nix-community/disko";

    simple-nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver/master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    kmonad = {
      url = "git+https://github.com/kmonad/kmonad?submodules=1&dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Generate System Images
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    snowfall-frost = {
      url = "github:snowfallorg/frost";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # INFO: https://github.com/snowfallorg/lib/issues/54#issuecomment-2067533982
    nixpkgs-mobile-nixos.url = "github:nixos/nixpkgs/0c56c244409eb4424611f37953bfd03c2534bcce";

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
        agenix.nixosModules.default
        disko.nixosModules.default
        home-manager.nixosModules.default
        kmonad.nixosModules.default
        icho.nixosModules.default
        nix-flatpak.nixosModules.nix-flatpak
        tmesh.nixosModules.default
      ];

      systems.modules.darwin = with inputs; [
        home-manager.darwinModules.default
        icho.nixosModules.default
        tmesh.nixosModules.default
      ];

      homes.modules = with inputs; [
        # tmesh.nixosModules.default
      ];

      systems.hosts.naka = {
        channelName = "nixpkgs-mobile-nixos";
      };

      overlays = with inputs; [
        snowfall-frost.overlays.default
      ];

      channels-config = {
        allowUnfree = true;
        # allowUnsupportedSystem = true;

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
