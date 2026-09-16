{
  description = "cairn";

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

    # herdr is not in nixpkgs. This is the upstream release binary, taken as an
    # input rather than a fetchurl so `nix flake update` can move it and
    # flake.lock records what shipped. file+https keeps Nix from trying to
    # unpack a bare executable as an archive.
    #
    # x86_64 only, which is all cairn has. Adding an aarch64 host means adding
    # the matching asset here; see modules/herdr.nix.
    herdr-bin = {
      url = "file+https://github.com/herdrdev/herdr/releases/download/v0.9.0/herdr-linux-x86_64";
      flake = false;
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
