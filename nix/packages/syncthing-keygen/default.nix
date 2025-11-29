{
  lib,
  writeShellApplication,
  syncthing,
  git,
  gnugrep,
  gnused,
  coreutils,
  inputs ? null,
  ...
}:
(writeShellApplication {
  name = "syncthing-keygen";
  runtimeInputs = [syncthing git gnugrep gnused coreutils];
  text = builtins.readFile ./syncthing-keygen.sh;
})
// {
  meta = with lib; {
    description = "Generate syncthing identity (key.pem and cert.pem) for a host";
    longDescription = ''
      syncthing-keygen generates syncthing identity files and extracts the device ID.
      It creates key.pem and cert.pem files, and provides instructions for encrypting
      them with agenix and adding the device ID to devices.nix.

      Usage: syncthing-keygen <hostname>
    '';
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "syncthing-keygen";
  };
}
