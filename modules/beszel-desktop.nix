# Desktop read-only Beszel data access. Quickshell never receives the token,
# only its runtime path; the helper owns authentication and transport.
let
  beszelStatus =
    pkgs:
    pkgs.writeShellApplication {
      name = "beszel-status";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.curl
        pkgs.jq
      ];
      text = builtins.readFile ./quickshell/beszel-status.sh;
    };
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.beszel-model = pkgs.runCommand "beszel-model" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
        node ${./quickshell/beszel-model.test.js} ${./quickshell/beszel-model.js}
        touch $out
      '';
      checks.beszel-status =
        pkgs.runCommand "beszel-status-test"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.bash
              pkgs.jq
              (beszelStatus pkgs)
            ];
          }
          ''
            node ${./quickshell/beszel-status.test.js} ${./quickshell/beszel-status.sh}
            test "$(BESZEL_MCP_TOKEN_FILE="$TMPDIR/missing-token" beszel-status)" = unavailable
            touch $out
          '';
    };

  nixos.modules.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      tokenFile = ../secrets/desktop + "/${config.networking.hostName}.yaml";
      hasToken = builtins.pathExists tokenFile;
    in
    {
      environment.systemPackages = [ (beszelStatus pkgs) ];
      sops.secrets = lib.optionalAttrs hasToken {
        beszel-mcp-token = {
          sopsFile = tokenFile;
          owner = "simon";
          mode = "0400";
        };
      };
      systemd.user.services.quickshell.environment = lib.optionalAttrs hasToken {
        BESZEL_MCP_TOKEN_FILE = config.sops.secrets.beszel-mcp-token.path;
      };
    };
}
