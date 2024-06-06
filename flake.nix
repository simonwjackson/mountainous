{
  # nixConfig = {
  #   extra-substituters = [
  #     "https://nix-community.cachix.org"
  #   ];
  #   extra-trusted-public-keys = [
  #     "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  #     "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  #     "hydra.nixos.org-1:CNHJZBh9K4tP3EKF6FkkgeVYsS3ohTl+oS0Qa8bezVs="
  #   ];
  # };

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

    backpacker = {
      url = "github:simonwjackson/backpacker";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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
        backpacker.nixosModules."_profiles/laptop"
        backpacker.nixosModules."_profiles/workspace"
        backpacker.nixosModules."desktops/hyprland"
        backpacker.nixosModules."desktops/plasma"
        backpacker.nixosModules."gaming/core"
        backpacker.nixosModules."gaming/emulation"
        backpacker.nixosModules."gaming/steam"
        backpacker.nixosModules."gaming/sunshine"
        backpacker.nixosModules."hardware/battery"
        backpacker.nixosModules."hardware/bluetooth"
        backpacker.nixosModules."hardware/cpu"
        backpacker.nixosModules."hardware/hybrid-sleep"
        backpacker.nixosModules."hardware/touchpad"
        backpacker.nixosModules."networking/core"
        backpacker.nixosModules."networking/secure-shell"
        backpacker.nixosModules."networking/tailscaled"
        backpacker.nixosModules."networking/zerotierone"
        backpacker.nixosModules.adb
        backpacker.nixosModules.agenix
        backpacker.nixosModules.boot
        backpacker.nixosModules.nix
        backpacker.nixosModules.performance
        backpacker.nixosModules.printing
        backpacker.nixosModules.security
        backpacker.nixosModules.sound
        backpacker.nixosModules.syncthing
        backpacker.nixosModules.user
        backpacker.nixosModules.vpn-proxy
        backpacker.nixosModules.waydroid

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
