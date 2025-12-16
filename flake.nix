{
  description = "My NixOS configurations";

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
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
    # Pinned nixpkgs for Immich - prevents breakage from upstream spacy/typer-slim issues
    nixpkgs-immich.url = "github:NixOS/nixpkgs/418468ac9527e799809c900eda37cbff999199b6";
    nixos-anywhere.url = "github:nix-community/nixos-anywhere";
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    hyprgrass = {
      url = "github:horriblename/hyprgrass";
      inputs.hyprland.follows = "hyprland";
    };
    disko.url = "github:nix-community/disko";
    impermanence.url = "github:nix-community/impermanence";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    taskwarrior-recurrence = {
      url = "github:lyz-code/taskwarrior_recurrence";
      flake = false;
    };
    synapse = {
      url = "github:miniArray/synapse";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    beads = {
      url = "github:steveyegge/beads";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flexget-webui = {
      url = "https://github.com/Flexget/webui/releases/download/2.0.29/dist.zip";
      flake = false;
    };
    gpd-fan-driver = {
      url = "github:Cryolitia/gpd-fan-driver";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    citron = {
      url = "github:simonwjackson/citron-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyxis = {
      url = "github:simonwjackson/pyxis";
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
        (final: prev: let
          # Import pinned nixpkgs for Immich to avoid spacy/typer-slim breakage
          pinnedPkgs = import inputs.nixpkgs-immich {
            inherit (final) system;
            config.allowUnfree = true;
          };
        in {
          # Pin Immich to working version
          immich = pinnedPkgs.immich;
          # Removed gamescope_git overlays - now using Jovian's stable packages
          neovim = inputs.icho.packages.${final.stdenv.hostPlatform.system}.default;
          synapse = inputs.synapse.packages.${final.stdenv.hostPlatform.system}.default;
          beads = inputs.beads.packages.${final.stdenv.hostPlatform.system}.default;
          citron = inputs.citron.packages.${final.stdenv.hostPlatform.system}.default;
          pyxis = inputs.pyxis.packages.${final.stdenv.hostPlatform.system}.default;
          obsidian = prev.symlinkJoin {
            name = "obsidian";
            paths = [prev.obsidian];
            buildInputs = [prev.makeWrapper];
            postBuild = ''
              wrapProgram $out/bin/obsidian \
                --add-flags "--enable-unsafe-webgpu" \
                --add-flags "--enable-features=Vulkan"
            '';
          };
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
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg:
            builtins.elem (inputs.nixpkgs.lib.getName pkg) [
              "graphite-cli"
            ];
        };
      in {
        default = pkgs.mkShell {
          packages = with pkgs; [
            just
            gum

            # Git
            graphite-cli

            # Lefthook
            lefthook

            # Nix
            alejandra

            # Shell
            shellcheck
            shfmt

            # Go
            go

            # Python
            black

            # Secrets
            gitleaks

            # AI
            inputs.beads.packages.${system}.default
          ];

          shellHook = ''
            lefthook install || true
          '';
        };
      });
    };
}
