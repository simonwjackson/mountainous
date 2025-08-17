{
  lib,
  inputs,
  pkgs,
  stdenv,
  python3,
  ...
}:
stdenv.mkDerivation {
  pname = "hinge-test";
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
    cp hinge-test.py $out/bin/hinge-test
    chmod +x $out/bin/hinge-test

    # Patch the shebang to use the correct Python interpreter
    substituteInPlace $out/bin/hinge-test \
      --replace "#!/usr/bin/env python3" "#!${python3}/bin/python3"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Hinge sensor testing tool for Lenovo Fold devices";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
