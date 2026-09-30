{
  description = "mountainous";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree.url = "github:denful/import-tree";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
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
    # Temporary: the unmerged nixpkgs update branch, which moves Korri onto
    # our nixpkgs revision. It exists only in the Korri checkout on zao, so
    # only zao can evaluate ibuki until it lands on korri-os/korri main.
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

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
