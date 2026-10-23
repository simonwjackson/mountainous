{
  description = "mountainous";

  nixConfig = {
    extra-substituters = "https://github.com/simonwjackson/nix-extras/releases/download/cache/";
    extra-trusted-public-keys = "nix-extras-ci-1:+Vcq7i6dPWOsOZjQwOduCEZOZZJznS/XfOcNUhFmg3Q=";
  };

  inputs = {
    pi.url = "github:lukasl-dev/pi.nix";
    pi-cliproxyapi-provider = {
      url = "github:router-for-me/pi-cliproxyapi-provider";
      flake = false;
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # ChicagoFLF 2.1: the font and README declare it Public Domain.
    chicagoflf-src = {
      url = "https://fontlibrary.org/assets/downloads/chicagoflf/a2e4a3d14e40fa7076a0a1bc06f3de43/chicagoflf.zip";
      flake = false;
    };

    # Keep its package pin: following ours would change the signed cache path.
    nix-extras.url = "github:simonwjackson/nix-extras";

    # Preserve Yari's deployed media releases during its ARM -> x86 move.
    # Application/database upgrades are separate from relocation.
    nixpkgs-media = {
      url = "github:NixOS/nixpkgs/c06b4ae3d6599a672a6210b7021d699c351eebda";
      flake = false;
    };

    # Rakku takes only its Home Assistant 2025.12.3 and Z-Wave JS 3.4.0 packages
    # from this pin. Upgrade them only as a separate, backed-up change.
    # gomod2nix-rakku and tests/fleet-sync-external.nix also use it.
    nixpkgs-rakku.url = "github:NixOS/nixpkgs/1306659b587dc277866c7b69eb97e5f07864d8c4";
    airconnect-src = {
      url = "https://github.com/philippe44/AirConnect/releases/download/1.9.2/AirConnect-1.9.2.zip";
      flake = false;
    };
    impermanence-rakku = {
      url = "github:nix-community/impermanence/4b3e914cdf97a5b536a889e939fb2fd2b043a170";
      flake = false;
    };
    gomod2nix-rakku = {
      url = "github:nix-community/gomod2nix/02e63a239d6eabd595db56852535992c898eba72";
      inputs.nixpkgs.follows = "nixpkgs-rakku";
    };

    # Sunshine tracks its newest release apart from the system pin, so a
    # Sunshine security fix does not wait on a whole-fleet nixpkgs bump.
    # `nix flake update nixpkgs-sunshine` moves it. See modules/sunshine.nix.
    nixpkgs-sunshine = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
      flake = false;
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree.url = "github:denful/import-tree";

    # The permafrost layer imports only nixos.nix, so none of this flake's own
    # inputs (home-manager, nixpkgs) are needed.
    impermanence = {
      url = "github:nix-community/impermanence";
      flake = false;
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Source-only inputs keep installer modules/tools pinned to this flake.
    nixos-images-src = {
      url = "github:nix-community/nixos-images";
      flake = false;
    };
    nixos-anywhere-src = {
      url = "github:nix-community/nixos-anywhere";
      flake = false;
    };

    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Korri keeps its own nixpkgs. Its product patches packages for exact
    # upstream versions, and its binary cache holds builds from that pin, so
    # a host that runs Korri is built from korri's nixpkgs, not ours.
    korri.url = "github:korri-os/korri";

    # herdr is not in nixpkgs. These are the upstream release binaries, taken
    # as inputs rather than fetchurl so `nix flake update` can move them and
    # flake.lock records what shipped. file+https keeps Nix from trying to
    # unpack a bare executable as an archive.
    #
    # One input per architecture, each named after the asset it holds. A single
    # One input per architecture keeps the release asset explicit.
    # modules/herdr.nix picks between them on the host platform.
    herdr-bin-x86_64 = {
      url = "file+https://github.com/herdrdev/herdr/releases/download/v0.9.0/herdr-linux-x86_64";
      flake = false;
    };

    herdr-bin-aarch64 = {
      url = "file+https://github.com/herdrdev/herdr/releases/download/v0.9.0/herdr-linux-aarch64";
      flake = false;
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
