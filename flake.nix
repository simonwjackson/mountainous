{
  description = "My NixOS configurations";

  inputs = {
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    nix-search-tv.url = "github:3timeslazy/nix-search-tv";
    elevate = {
      url = "github:simonwjackson/elevate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    icho = {
      url = "github:simonwjackson/icho";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ryujinx.url = "github:Naxdy/Ryujinx";
    tmesh.url = "github:simonwjackson/tmesh";
    auto-cpufreq = {
      url = "github:AdnanHodzic/auto-cpufreq";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    hyprland.url = "github:hyprwm/Hyprland";
    disko.url = "github:nix-community/disko";
    impermanence.url = "github:nix-community/impermanence";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: let
    utils = import ./utils.nix {inherit inputs;};
  in
    utils.mkFlake {
      inherit inputs;
      namespace = "mountainous";
      overlays = with inputs; [
        (final: prev: {
          gamescope_git = chaotic.packages.${prev.system}.gamescope_git;
          "gamescope-wsi_git" = chaotic.packages.${prev.system}."gamescope-wsi_git";
        })
      ];
    };
}
