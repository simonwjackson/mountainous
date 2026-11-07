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
      defaultThinkingLevel = "medium";
      compaction = {
        enabled = true;
        reserveTokens = 16384;
        keepRecentTokens = 20000;
      };
      retry.provider = {
        timeoutMs = 900000;
        maxRetryDelayMs = 60000;
        maxRetries = 2;
      };
      packages = [ (toString provider) ];
    }
  );
in
{
  secrets."${name}-pi-cliproxyapi" = ".pi/agent/cliproxyapi.json";
  readOnlyBinds = [ "${settings}:/var/lib/${name}/.pi/agent/settings.json" ];
}
