{pkgs ? import <nixpkgs> {}}: rec {
  xpo = pkgs.callPackage ./xpo {};
  vinyl-vault = pkgs.callPackage ./vinyl-vault {};
  # ex = pkgs.callPackage ./ex { };
  nest-tmux = pkgs.callPackage ./nest-tmux {};
}
