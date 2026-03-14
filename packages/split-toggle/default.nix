{
  lib,
  stdenv,
  makeWrapper,
  bash,
  jq,
  hyprland,
  gawk,
  coreutils,
  ...
}:
stdenv.mkDerivation rec {
  pname = "split-toggle";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall

    install -Dm755 split-toggle.sh $out/bin/split-toggle

    wrapProgram $out/bin/split-toggle \
      --prefix PATH : ${lib.makeBinPath [
      bash
      jq
      hyprland
      gawk
      coreutils
    ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Toggle between golden ratio and even split layouts in Hyprland";
    longDescription = ''
      A tool to toggle between golden ratio (0.618) and even split (0.5) layouts
      in Hyprland's master layout. Automatically detects the current split ratio
      and toggles to the opposite.
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "split-toggle";
  };
}
