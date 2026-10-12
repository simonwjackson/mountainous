{
  description = "mountainous";

  nixConfig = {
    extra-substituters = "https://github.com/simonwjackson/nix-extras/releases/download/cache/";
    extra-trusted-public-keys = "nix-extras-ci-1:+Vcq7i6dPWOsOZjQwOduCEZOZZJznS/XfOcNUhFmg3Q=";
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Keep its package pin: following ours would change the signed cache path.
    nix-extras.url = "github:simonwjackson/nix-extras";

    # Preserve Yari's deployed media releases during its ARM -> x86 move.
    # Application/database upgrades are separate from relocation.
    nixpkgs-media = {
      url = "github:NixOS/nixpkgs/c06b4ae3d6599a672a6210b7021d699c351eebda";
      flake = false;
    };

    # Rakku's first Cairn deployment preserves its running HA 2025.12.3 and
    # Z-Wave JS 3.4.0 environment. Upgrade only as a separate, backed-up change.
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
    #
    # Temporary: the unmerged nixpkgs update branch (Sway 1.12, systemd
    # 261.2, runtime UID 56774), rebased on Korri main. It exists only in the
    # Korri checkout on zao, so only zao can evaluate ibuki until it lands on
    # korri-os/korri main.
    korri.url = "git+file:///home/simonwjackson/code/sandbox/korri?ref=work/nixpkgs-sway-112";

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
