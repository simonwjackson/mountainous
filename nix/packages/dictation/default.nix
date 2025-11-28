{
  lib,
  stdenv,
  makeWrapper,
  bash,
  sox,
  wtype,
  coreutils,
  procps,
  openssh,
  inputs,
  ...
}:
stdenv.mkDerivation rec {
  pname = "dictation";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  stt = inputs.speech.packages.${stdenv.hostPlatform.system}.default;

  installPhase = ''
    runHook preInstall

    install -Dm755 dictation.sh $out/bin/dictation

    wrapProgram $out/bin/dictation \
      --prefix PATH : ${lib.makeBinPath [
      bash
      sox
      wtype
      coreutils
      procps
      openssh
    ]}:${stt}/bin

    runHook postInstall
  '';

  meta = with lib; {
    description = "Hold-to-dictate speech-to-text for Wayland";
    longDescription = ''
      A tool for speech-to-text dictation in Wayland. Press once to start
      recording, press again to stop and type the transcription. Includes
      ambient sound effects and waiting tones.
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "dictation";
  };
}
