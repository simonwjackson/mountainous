# Read-only MCP server for the Beszel hub (github.com/maxbth/beszel-mcp), next to
# the hub on the host with the `beszel-hub` layer.
#
# It logs in to the hub as `beszel-mcp@…`, a Beszel user with role `readonly`;
# beszel-mcp-user.service creates or repairs that login through the hub's API.
# The hub runs with SHARE_ALL_SYSTEMS so this login sees every system.
#
# Clients reach https://beszel-mcp.<tailnet>/mcp with `Authorization: Bearer
# <beszel-mcp-token>` from secrets/beszel/hub.yaml. The server itself listens on
# loopback only.
{
  inputs,
  self,
  ...
}:
let
  version = "1.0.0";
  port = 8092;
  tailnet = "hummingbird-lake.ts.net";
  email = "beszel-mcp@${tailnet}";
  provision = ./beszel-mcp-user.py;
in
{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
        beszel-mcp =
          let
            src = inputs.beszel-mcp;
            # Bun resolves the locked dependencies; the hash pins the result.
            modules = pkgs.stdenvNoCC.mkDerivation {
              pname = "beszel-mcp-node-modules";
              inherit version src;
              nativeBuildInputs = [
                pkgs.bun
                pkgs.writableTmpDirAsHomeHook
              ];
              dontConfigure = true;
              buildPhase = ''
                runHook preBuild
                bun install --frozen-lockfile --production --ignore-scripts --no-progress
                runHook postBuild
              '';
              installPhase = ''
                runHook preInstall
                mkdir -p $out
                cp -r node_modules $out/
                runHook postInstall
              '';
              dontFixup = true;
              outputHashMode = "recursive";
              outputHashAlgo = "sha256";
              outputHash = "sha256-BzJS9M0fx/7LKsX2a37Qy3y2BtA5fZv0CXRACIR7av8=";
            };
          in
          pkgs.stdenvNoCC.mkDerivation {
            pname = "beszel-mcp";
            inherit version src;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            dontBuild = true;
            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib/beszel-mcp $out/bin
              cp -r package.json tsconfig.json src $out/lib/beszel-mcp/
              ln -s ${modules}/node_modules $out/lib/beszel-mcp/node_modules
              makeWrapper ${pkgs.bun}/bin/bun $out/bin/beszel-mcp \
                --add-flags "run $out/lib/beszel-mcp/src/index.ts" \
                --set BUN_RUNTIME_TRANSPILER_CACHE_PATH 0
              runHook postInstall
            '';
            meta = {
              description = "Read-only MCP server for a Beszel monitoring hub";
              homepage = "https://github.com/maxbth/beszel-mcp";
              license = lib.licenses.mit;
              mainProgram = "beszel-mcp";
            };
          };
      };
    };

  nixos.modules.beszel-hub =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      secrets = config.sops.secrets;
      hubFile = ../secrets/beszel/hub.yaml;
      hub = "http://127.0.0.1:${toString config.services.beszel.hub.port}";
    in
    {
      services.beszel.hub.environment.SHARE_ALL_SYSTEMS = "true";

      sops.secrets = {
        beszel-mcp-password = {
          sopsFile = hubFile;
          mode = "0400";
          restartUnits = [
            "beszel-mcp-user.service"
            "beszel-mcp.service"
          ];
        };
        beszel-mcp-token = {
          sopsFile = hubFile;
          mode = "0400";
          restartUnits = [ "beszel-mcp.service" ];
        };
      };
      sops.templates."beszel-mcp.env" = {
        content = ''
          BESZEL_PASSWORD=${config.sops.placeholder.beszel-mcp-password}
          MCP_AUTH_TOKEN=${config.sops.placeholder.beszel-mcp-token}
        '';
        mode = "0400";
        restartUnits = [ "beszel-mcp.service" ];
      };

      systemd.services.beszel-mcp-user = {
        description = "Provision the read-only Beszel login for beszel-mcp";
        requires = [ "beszel-hub.service" ];
        after = [ "beszel-hub.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          # Reads the hub database; every write goes through the hub's API.
          User = "beszel-hub";
          Group = "beszel-hub";
          LoadCredential = [ "password:${secrets.beszel-mcp-password.path}" ];
          ExecStart = lib.escapeShellArgs [
            "${pkgs.python3}/bin/python3"
            "${provision}"
            "--hub"
            hub
            "--db"
            "${config.services.beszel.hub.dataDir}/beszel_data/data.db"
            "--email"
            email
            "--password-file"
            "%d/password"
          ];
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
        };
      };

      systemd.services.beszel-mcp = {
        description = "Read-only MCP server for the Beszel hub";
        wantedBy = [ "multi-user.target" ];
        requires = [ "beszel-mcp-user.service" ];
        after = [ "beszel-mcp-user.service" ];
        environment = {
          BESZEL_URL = hub;
          BESZEL_EMAIL = email;
          MCP_TRANSPORT = "http";
          MCP_HOST = "127.0.0.1";
          MCP_PORT = toString port;
          HOME = "/tmp";
        };
        serviceConfig = {
          ExecStart = "${self.packages.${pkgs.stdenv.hostPlatform.system}.beszel-mcp}/bin/beszel-mcp";
          EnvironmentFile = config.sops.templates."beszel-mcp.env".path;
          DynamicUser = true;
          Restart = "always";
          RestartSec = "10s";
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ProtectKernelTunables = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          UMask = "0077";
        };
      };

      mountainous.tailnetNames.beszel-mcp = {
        description = "Beszel MCP tailnet proxy";
        backend = "http://127.0.0.1:${toString port}";
        after = [ "beszel-mcp.service" ];
      };
    };
}
