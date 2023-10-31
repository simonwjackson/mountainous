{pkgs ? import <nixpkgs> {}}: rec {
  xpo = pkgs.callPackage ./xpo {};
  vinyl-vault = pkgs.callPackage ./vinyl-vault {};
  herbstluftwm-scripts = pkgs.callPackage ./herbstluftwm-scripts {};
  # ex = pkgs.callPackage ./ex { };
  nest-tmux = pkgs.callPackage ./nest-tmux {};
  # mpvd = pkgs.callPackage ./mvpd {};
}
