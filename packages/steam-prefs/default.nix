{
  lib,
  python3Packages,
  ...
}:
python3Packages.buildPythonApplication {
  pname = "steam-prefs";
  version = "1.0.0";

  src = ./.;

  format = "other";

  propagatedBuildInputs = with python3Packages; [
    vdf
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp $src/steam-prefs.py $out/bin/steam-prefs
    chmod +x $out/bin/steam-prefs
    runHook postInstall
  '';

  meta = with lib; {
    description = "Declarative Steam preferences manager for NixOS";
    longDescription = ''
      steam-prefs patches Steam's localconfig.vdf to manage Friends/Chat settings
      declaratively. It preserves existing settings while updating configured values.
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "steam-prefs";
  };
}
