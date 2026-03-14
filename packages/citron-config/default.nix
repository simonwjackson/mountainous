{
  lib,
  python3,
  ...
}:
python3.pkgs.buildPythonApplication {
  pname = "citron-config";
  version = "1.0.0";
  format = "other";

  src = ./.;

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp citron-config.py $out/bin/citron-config
    chmod +x $out/bin/citron-config
    runHook postInstall
  '';

  meta = with lib; {
    description = "Declarative configuration manager for Citron Nintendo Switch emulator";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
