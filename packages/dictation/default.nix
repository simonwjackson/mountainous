{
  lib,
  stdenv,
  makeWrapper,
  bash,
  curl,
  ironbar,
  sox,
  wl-clipboard,
  wtype,
  coreutils,
  ...
}:
stdenv.mkDerivation {
  pname = "dictation";
  version = "2.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall

    install -Dm755 dictation.sh $out/bin/dictation

    wrapProgram $out/bin/dictation \
      --prefix PATH : ${lib.makeBinPath [
      bash
      curl
      ironbar
      sox
      wl-clipboard
      wtype
      coreutils
    ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Press-to-dictate speech-to-text via Groq Whisper API";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "dictation";
  };
}
