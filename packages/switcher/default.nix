{
  lib,
  writeShellApplication,
  jq,
}:
writeShellApplication {
  name = "switcher";
  runtimeInputs = [];
  text = builtins.readFile ./switcher.sh;
}
// {
  meta = with lib; {
    licenses = licenses.mit;
    platforms = platforms.all;
  };
}
