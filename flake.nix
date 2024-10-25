{
  inputs = {
    secrets = {
      url = "github:simonwjackson/secrets";
      flake = false;
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    auto-cpufreq = {
      url = "github:AdnanHodzic/auto-cpufreq";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko.url = "github:nix-community/disko";

    elevate = {
      url = "github:simonwjackson/elevate";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gamerack.url = "https://flakehub.com/f/simonwjackson/gamerack/*.tar.gz";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    icho.url = "github:simonwjackson/icho";

    mobile-nixos = {
      url = "github:NixOS/mobile-nixos";
      flake = false;
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.4.1";

    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-firefox-darwin.url = "github:bandithedoge/nixpkgs-firefox-darwin";

    # INFO: https://github.com/snowfallorg/lib/issues/54#issuecomment-2067533982
    nixpkgs-mobile-nixos.url = "github:nixos/nixpkgs/0c56c244409eb4424611f37953bfd03c2534bcce";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nur.url = "github:nix-community/NUR";

    ryujinx.url = "github:Naxdy/Ryujinx";

    simple-nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver/master";
      inputs = {nixpkgs.follows = "nixpkgs";};
    };

    snowfall-frost = {
      url = "github:snowfallorg/frost";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tmesh.url = "github:simonwjackson/tmesh";
  };

  outputs = inputs: let
    snowfallOutputs = inputs.snowfall-lib.mkFlake {
      inherit inputs;
      src = ./.;

      systems.modules.nixos = with inputs; [
        agenix.nixosModules.default
        disko.nixosModules.default
        home-manager.nixosModules.default
        icho.nixosModules.default
        nix-flatpak.nixosModules.nix-flatpak
        tmesh.nixosModules.default
        nur.nixosModules.nur
        ryujinx.nixosModules.default
      ];

      systems.modules.darwin = with inputs; [
        home-manager.darwinModules.default
        icho.nixosModules.default
        tmesh.nixosModules.default
      ];

      systems.hosts.naka = {
        channelName = "nixpkgs-mobile-nixos";
      };

      homes.modules = with inputs; [
        # elevate.homeModules.service
      ];

      overlays = with inputs; [
        snowfall-frost.overlays.default
        nur.overlay
        (final: prev: {
          proton-ge-custom = chaotic.packages.${prev.system}.proton-ge-custom;
          gamescope_git = chaotic.packages.${prev.system}.gamescope_git;
          gamescope-wsi_git = chaotic.packages.${prev.system}.gamescope-wsi_git;
        })
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
  in
    snowfallOutputs;
}
