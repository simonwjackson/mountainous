# Pillow, numpy and librsvg follow the repository's locked nixpkgs input.
{ pkgs }:
let
  python = pkgs.python3.withPackages (p: [
    p.pillow
    p.numpy
  ]);
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "mountainous-platinum-icons";
  version = "1";
  dontUnpack = true;
  nativeBuildInputs = [ pkgs.makeWrapper ];
  installPhase = ''
    mkdir -p "$out/lib/mountainous-icons" "$out/bin"
    cp ${../scripts/platinum_icons.py} "$out/lib/mountainous-icons/platinum_icons.py"
    cp ${../scripts/platinum-icon.py} "$out/lib/mountainous-icons/platinum-icon.py"
    cp ${../scripts/platinum-app-tokens.py} "$out/lib/mountainous-icons/platinum-app-tokens.py"
    makeWrapper ${python}/bin/python3 "$out/bin/mountainous-platinum-icon" \
      --add-flags "$out/lib/mountainous-icons/platinum-icon.py" \
      --set RSVG_CONVERT ${pkgs.librsvg}/bin/rsvg-convert \
      --set OPENBLAS_NUM_THREADS 1 --set OMP_NUM_THREADS 1
    # Build-time strip art for a host's apps (desktop-art.nix, extraSetup).
    makeWrapper ${python}/bin/python3 "$out/bin/mountainous-platinum-app-tokens" \
      --add-flags "$out/lib/mountainous-icons/platinum-app-tokens.py" \
      --set RSVG_CONVERT ${pkgs.librsvg}/bin/rsvg-convert \
      --set OPENBLAS_NUM_THREADS 1 --set OMP_NUM_THREADS 1
  '';
  passthru = { inherit python; };
  meta = {
    description = "Deterministic Platinum tokens for arbitrary favicons";
    platforms = pkgs.lib.platforms.linux;
    mainProgram = "mountainous-platinum-icon";
  };
}
