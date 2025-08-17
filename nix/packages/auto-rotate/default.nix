{
  lib,
  inputs,
  pkgs,
  stdenv,
  python3,
  ...
}:
stdenv.mkDerivation {
  pname = "auto-rotate";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [
    python3
  ];

  buildInputs = [
    python3
  ];

  installPhase = ''
    runHook preInstall

    # Create bin directory
    mkdir -p $out/bin

    # Install the Python script
    cp auto-rotate.py $out/bin/auto-rotate
    chmod +x $out/bin/auto-rotate

    # Patch the shebang to use the correct Python interpreter
    substituteInPlace $out/bin/auto-rotate \
      --replace "#!/usr/bin/env python3" "#!${python3}/bin/python3"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Automatic screen rotation service for Lenovo Fold devices with Hyprland";
    longDescription = ''
      A service that monitors accelerometer and hinge sensors to automatically
      rotate the display on Lenovo Fold devices when using Hyprland compositor.
      Features orientation detection, tablet mode detection, and debouncing.
    '';
    homepage = "https://github.com/simonwjackson/mountainous";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [];
  };
}
