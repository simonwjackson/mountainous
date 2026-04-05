{
  lib,
  python3Packages,
}:
python3Packages.buildPythonApplication {
  pname = "evdev-hotkey";
  version = "1.0.0";

  src = ./.;
  format = "other";

  propagatedBuildInputs = [
    python3Packages.evdev
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 evdev_hotkey.py $out/bin/evdev-hotkey
    runHook postInstall
  '';

  meta = with lib; {
    description = "Generic evdev hotkey daemon — watch input devices and run commands on key press";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "evdev-hotkey";
  };
}
