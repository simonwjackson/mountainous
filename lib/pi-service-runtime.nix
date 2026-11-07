# Isolate an embedded Pi model runtime from the operator's mutable home.
{
  pkgs,
  inputs,
  name,
}:
let
  provider = pkgs.runCommand "${name}-pi-cliproxyapi-provider" { } ''
    mkdir -p "$out"
    cp -r ${inputs.pi-cliproxyapi-provider}/. "$out/"
  '';
  settings = pkgs.writeText "${name}-pi-settings.json" (
    builtins.toJSON {
      defaultProvider = "cliproxyapi";
      defaultModel = "claude-opus-5-5";
      packages = [ (toString provider) ];
    }
  );
in
{
  secrets."${name}-pi-cliproxyapi" = ".pi/agent/cliproxyapi.json";
  readOnlyBinds = [ "${settings}:/var/lib/${name}/.pi/agent/settings.json" ];
}
