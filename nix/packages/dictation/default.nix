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

    # Install both local and remote scripts
    install -Dm755 dictation-local.sh $out/bin/dictation-local
    install -Dm755 dictation-remote.sh $out/bin/dictation-remote

    # Create 'dictation' as symlink to local by default
    ln -s dictation-local $out/bin/dictation

    # Wrap local script (includes whisper-cpp)
    wrapProgram $out/bin/dictation-local \
      --prefix PATH : ${lib.makeBinPath [
      bash
      sox
      wtype
      coreutils
      procps
      whisper-cpp
    ]}

    # Wrap remote script (includes openssh, no whisper-cpp needed)
    wrapProgram $out/bin/dictation-remote \
      --prefix PATH : ${lib.makeBinPath [
      bash
      sox
      wtype
      coreutils
      procps
      openssh
    ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Hold-to-dictate speech-to-text for Wayland";
    longDescription = ''
      A tool for speech-to-text dictation in Wayland. Press once to start
      recording, press again to stop and type the transcription. Includes
      ambient sound effects and waiting tones.

      - dictation-local: Uses whisper-cli locally
      - dictation-remote: Sends audio to remote host via SSH
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "dictation";
  };
}
