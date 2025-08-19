{
  lib,
  stdenv,
  makeWrapper,
  bash,
  ddcutil,
  brightnessctl,
  coreutils,
  gnugrep,
  gawk,
  ...
}:

stdenv.mkDerivation rec {
  pname = "brightness-sync";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    # Install the main script
    install -Dm755 brightness-sync.sh $out/bin/brightness-sync

    # Wrap the script with required dependencies in PATH
    wrapProgram $out/bin/brightness-sync \
      --prefix PATH : ${lib.makeBinPath [
        bash
        ddcutil
        brightnessctl
        coreutils
        gnugrep
        gawk
      ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Synchronize brightness across internal and external displays";
    longDescription = ''
      A tool to synchronize brightness settings between internal laptop displays
      (using backlight interfaces) and external monitors (using DDC/CI protocol).
      Supports manual synchronization and automatic monitoring modes.
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "brightness-sync";
  };
}