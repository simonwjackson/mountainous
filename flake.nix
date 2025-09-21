{
  description = "My NixOS configurations";

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    jovian.follows = "chaotic/jovian";
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    vpn-confinement = {
      url = "github:Maroka-chan/VPN-Confinement";
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
        gomod2nix.overlays.default
        (final: prev: {
          # Removed gamescope_git overlays - now using Jovian's stable packages
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
