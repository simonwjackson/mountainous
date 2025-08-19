{
  description = "My NixOS configurations";

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
          neovim = inputs.icho.packages.${final.system}.default;
        })
      ];
    }
    // {
      formatter = inputs.nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"] (
        system: let
          pkgs = import inputs.nixpkgs {inherit system;};
        in
          pkgs.alejandra
      );

      devShells = inputs.nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"] (system: let
        pkgs = import inputs.nixpkgs {inherit system;};
      in {
        default = pkgs.mkShell {
          packages = with pkgs; [
            just
            gum
          ];
        };
      });
    };
}
