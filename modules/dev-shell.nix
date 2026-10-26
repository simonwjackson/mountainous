# Repository tools come from the same nixpkgs pin as the systems.
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [ pkgs.lefthook ];
      };

      checks.lefthook =
        pkgs.runCommand "lefthook-pre-push"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.gitMinimal
              pkgs.gnugrep
              pkgs.lefthook
            ];
          }
          ''
            bash ${../tests/lefthook.sh} ${../lefthook.yml} ${../scripts/check-flake-inputs.sh}
            touch $out
          '';
    };
}
