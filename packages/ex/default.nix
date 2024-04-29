{
  lib,
  writeShellApplication,
  gnutar,
  bzip2,
  p7zip,
  gzip,
}:
(writeShellApplication {
  name = "ex";
  runtimeInputs = [gnutar bzip2 p7zip gzip];
  text = builtins.readFile ./ex.sh;
})
// {
  meta = with lib; {
    licenses = licenses.mit;
    platforms = platforms.all;
  };
}
