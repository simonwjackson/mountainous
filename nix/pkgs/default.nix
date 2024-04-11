{pkgs ? import <nixpkgs> {}}: rec {
  # mpvd = pkgs.callPackage ./mvpd {};
  cpu-profile = pkgs.callPackage ./cpu-profile {};
  ex = pkgs.callPackage ./ex {};
  herbstluftwm-scripts = pkgs.callPackage ./herbstluftwm-scripts {};
  # nest-tmux = pkgs.callPackage ./nest-tmux {};
  popup-term = pkgs.callPackage ./popup-term {};
  vinyl-vault = pkgs.callPackage ./vinyl-vault {};
  wifi-select = pkgs.callPackage ./wifi-select {};
  xpo = pkgs.callPackage ./xpo {};
}
