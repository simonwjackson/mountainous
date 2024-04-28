{
  pkgs,
  inputs,
  system,
  ...
}: let
  pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
    src = ./.;
    hooks = {
      deadnix.enable = true;
      nixpkgs-fmt.enable = true;
      statix.enable = true;
      typos.enable = true;
      actionlint.enable = true;
    };
  };
in
  pkgs.mkShell {
    buildInputs = with pkgs; [
      cachix
      deadnix
      nil
      just
    ];
    inherit (pre-commit-check) shellHook;
  }
