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
  whisper-cpp,
  ...
}:
stdenv.mkDerivation rec {
  pname = "dictation";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall

    # Install unified script
    install -Dm755 dictation.sh $out/bin/dictation

    # Wrap with all dependencies (local and remote)
    wrapProgram $out/bin/dictation \
      --prefix PATH : ${lib.makeBinPath [
      bash
      sox
      wtype
      coreutils
      procps
      openssh
      whisper-cpp
    ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Hold-to-dictate speech-to-text for Wayland";
    longDescription = ''
      A tool for speech-to-text dictation in Wayland. Press once to start
      recording, press again to stop and type the transcription. Includes
      ambient sound effects and waiting tones.

      Mode is determined by DICTATION_REMOTE_HOST:
      - If set: sends audio to remote host via SSH
      - If unset or --local flag: uses whisper-cli locally
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "dictation";
  };
}
