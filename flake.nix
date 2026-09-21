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

    # linux-firmware has only the Glymur reference topology. Pin the upstream
    # AudioReach sources that add the UX3607OA's S32_LE microphone graph.
    audioreach-topology = {
      url = "github:linux-msm/audioreach-topology/993a17dcb672357998a463a73f120064d6c74f4f";
      flake = false;
    };

    # herdr is not in nixpkgs. These are the upstream release binaries, taken
    # as inputs rather than fetchurl so `nix flake update` can move them and
    # flake.lock records what shipped. file+https keeps Nix from trying to
    # unpack a bare executable as an archive.
    #
    # One input per architecture, each named after the asset it holds. A single
    # `herdr-bin` read fine while every host was x86_64. myoko is aarch64, and
    # at that point the name no longer said which machine it was for.
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
