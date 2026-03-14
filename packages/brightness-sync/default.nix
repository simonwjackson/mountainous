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
  bc,
  hyprland,
  ...
}:
stdenv.mkDerivation rec {
  pname = "brightness-sync";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall

    # Install the main script (legacy, for multi-monitor sync)
    install -Dm755 brightness-sync.sh $out/bin/brightness-sync

    # Install extended brightness script (seamless hw->sw dimming)
    install -Dm755 brightness-extended.sh $out/bin/brightness-extended

    # Wrap the sync script with required dependencies in PATH
    wrapProgram $out/bin/brightness-sync \
      --prefix PATH : ${lib.makeBinPath [
      bash
      ddcutil
      brightnessctl
      coreutils
      gnugrep
      gawk
    ]}

    # Wrap the extended script with required dependencies in PATH
    wrapProgram $out/bin/brightness-extended \
      --prefix PATH : ${lib.makeBinPath [
      bash
      brightnessctl
      coreutils
      bc
      hyprland
    ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Brightness control with software dimming below hardware minimum";
    longDescription = ''
      Two brightness tools:
      - brightness-sync: Synchronize brightness between internal and external displays
      - brightness-extended: Seamless brightness control that uses hardware backlight
        until minimum, then continues with software gamma dimming via Hyprland shader
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "brightness-extended";
  };
}
