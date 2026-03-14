{
  lib,
  stdenv,
  makeWrapper,
  bash,
  jq,
  hyprland,
  gawk,
  gnugrep,
  coreutils,
  ...
}:
stdenv.mkDerivation rec {
  pname = "scale-adjust";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall

    install -Dm755 scale-adjust.sh $out/bin/scale-adjust

    wrapProgram $out/bin/scale-adjust \
      --prefix PATH : ${lib.makeBinPath [
      bash
      jq
      hyprland
      gawk
      gnugrep
      coreutils
    ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Adjust Hyprland monitor scale with resolution-aware valid scales";
    longDescription = ''
      A tool to adjust monitor scaling in Hyprland. Supports adjusting individual
      monitors or all monitors simultaneously. Automatically calculates valid
      scales based on resolution to avoid fractional scaling artifacts.
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "scale-adjust";
  };
}
