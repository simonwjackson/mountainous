{ inputs, self, ... }:
let
  rows = import ../lib/ai-mcp-rows.nix;
  nodes = import ../lib/tailnet-nodes.nix;
in
{
  perSystem = { pkgs, lib, ... }: {
    checks.mindwtr =
      assert import ../tests/mindwtr-contract.nix {
        rakku = self.nixosConfigurations.rakku.config;
        yari = self.nixosConfigurations.yari.config;
        inherit lib;
      };
      pkgs.runCommand "mindwtr-contract" { } "touch $out";
  };
  nixos.modules.mindwtr =
    { config, lib, ... }:
    let
      cfg = config.services.mindwtr;
      persistence = { options, ... }: {
        config = lib.optionalAttrs (options.environment ? persistence) {
          users.users.mindwtr.uid = 951;
          users.groups.mindwtr.gid = 951;
          environment.persistence."/tundra/permafrost".directories = [
            {
              directory = cfg.stateDir;
              user = "mindwtr";
              group = "mindwtr";
              mode = "0700";
            }
          ];
        };
      };
    in
    {
      imports = [
        inputs.mindwtr.nixosModules.default
        persistence
      ];
      services.mindwtr = {
        enable = lib.mkDefault true;
        cloud = {
          port = 8787;
          tokenFile = config.sops.secrets.mindwtr-cloud-token.path;
        };
        web = {
          enable = true;
          port = 4592;
          cloudUrl = "https://tasks.hummingbird-lake.ts.net";
        };
        mcp = {
          enable = true;
          port = 8723;
          write = true;
          tokenFile = config.sops.secrets.mindwtr-mcp-token.path;
        };
      };
      systemd.services.mindwtr-cloud = {
        unitConfig.RequiresMountsFor = [ cfg.stateDir ];
        environment = {
          NODE_ENV = "production";
          MINDWTR_CLOUD_CORS_ORIGIN = cfg.web.cloudUrl;
        };
        serviceConfig = {
          MemoryHigh = "384M";
          MemoryMax = "768M";
        };
      };
      systemd.services.mindwtr-mcp.serviceConfig = {
        MemoryHigh = "384M";
        MemoryMax = "768M";
      };
      mountainous.tailnetNames = {
        tasks = {
          backend = "http://127.0.0.1:4592";
          after = [
            "nginx.service"
            "mindwtr-cloud.service"
          ];
          description = "Mindwtr GTD web app and Cloud sync API";
        };
        ai.mcpRoutes.mindwtr = {
          backend = "http://127.0.0.1:8723/mcp";
          callerNodeIds = map (node: nodes.${node}) rows.mindwtr.callers;
          mcpTools = rows.mindwtr.tools;
          bearerCredentialFile = cfg.mcp.tokenFile;
        };
      };
      sops.secrets = {
        mindwtr-cloud-token = {
          sopsFile = ../secrets/hosts/rakku.yaml;
          mode = "0400";
          restartUnits = [
            "mindwtr-cloud.service"
            "mindwtr-mcp.service"
          ];
        };
        mindwtr-mcp-token = {
          sopsFile = ../secrets/hosts/rakku.yaml;
          mode = "0400";
          restartUnits = [
            "mindwtr-mcp.service"
            "tsnet-proxy-ai.service"
          ];
        };
      };
    };
}
