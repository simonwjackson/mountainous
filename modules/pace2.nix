# Pace 2's alerts slice. Do not reuse the quarantined Pace 1 profile.
{ inputs, self, ... }:
{
  nixos.modules.pace2 =
    { config, lib, ... }:
    let
      rows = import ../lib/ai-mcp-rows.nix;
      nodes = import ../lib/tailnet-nodes.nix;
      secret = name: {
        sopsFile = ../secrets/hosts/rakku.yaml;
        mode = "0400";
        restartUnits = [
          "pace2.service"
        ]
        ++ lib.optional (name != "simplefin-access-url") "tsnet-proxy-ai.service";
      };
      route = row: person: {
        backend = "http://127.0.0.1:3195/mcp";
        callerNodeIds = map (node: nodes.${node}) rows.${row}.callers;
        mcpTools = rows.${row}.tools;
        mcpResources = [
          "ui://pace/status"
          "ui://pace/overview"
          "ui://pace/change"
          "ui://pace/alerts"
        ];
        bearerCredentialFile = config.sops.secrets."pace-key-${person}".path;
      };
    in
    {
      users.groups.pace2 = { };
      users.users.pace2 = {
        isSystemUser = true;
        group = "pace2";
        home = "/var/lib/pace2";
      };
      sops.secrets =
        (lib.genAttrs [ "pace-key-simon" "pace-key-laure" "simplefin-access-url" ] secret)
        // {
          # ai-gateway declares this same root-only host secret and its own restart.
          ai-gateway-key-pace-rakku = lib.mkIf config.mountainous.features.ai-gateway.enable {
            restartUnits = lib.mkAfter [
              "pace2.service"
              "tsnet-proxy-ai.service"
            ];
          };
        };
      environment.persistence."/tundra/permafrost".directories = [
        {
          directory = "/var/lib/pace2";
          user = "pace2";
          group = "pace2";
          mode = "0700";
        }
      ];
      # The initial database is copied before activation, while no Pace 2 process exists.
      systemd.tmpfiles.rules = [ "z /var/lib/pace2/pace.sqlite 0600 pace2 pace2 - -" ];
      systemd.services.pace2 = {
        description = "Pace 2 household savings goals and Budgets (read-only MCP)";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment = {
          HOST = "127.0.0.1";
          PORT = "3195";
          TZ = "America/Denver";
          PACE_SYNC = "on";
          PACE_MODEL_URL = "https://ai.hummingbird-lake.ts.net/v1/chat/completions";
          PACE_MODEL = "gemini-3.8-flash-high";
          # Admission logs name only the person and HTTP method, never financial content.
          RUST_LOG = "pace=info,pace::http=debug";
        };
        # SimpleFIN uses outbound HTTPS; the sandbox does not restrict destinations.
        serviceConfig = {
          ExecStart = "${inputs.pace-service.packages.x86_64-linux.default}/bin/pace serve";
          User = "pace2";
          Group = "pace2";
          StateDirectory = "pace2";
          StateDirectoryMode = "0700";
          LoadCredential =
            map (name: "${name}:${config.sops.secrets.${name}.path}") [
              "pace-key-simon"
              "pace-key-laure"
              "simplefin-access-url"
            ]
            ++ lib.optional config.mountainous.features.ai-gateway.enable "pace-model-key:${config.sops.secrets.ai-gateway-key-pace-rakku.path}";
          Restart = "on-failure";
          RestartSec = "5s";
          UMask = "0077";
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          NoNewPrivileges = true;
          CapabilityBoundingSet = "";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          SystemCallFilter = [ "@system-service" ];
          SystemCallErrorNumber = "EPERM";
          MemoryDenyWriteExecute = true;
          LockPersonality = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          RestrictRealtime = true;
          ReadWritePaths = [ "/var/lib/pace2" ];
        };
      };
      mountainous.tailnetNames.ai = lib.mkIf config.mountainous.features.ai-gateway.enable {
        mcpRoutes.pace = route "pace" "simon";
        mcpRoutes.pace-laure = route "pace-laure" "laure";
      };
    };
  perSystem =
    { pkgs, lib, ... }:
    {
      checks.pace2 =
        assert import ../tests/pace2.nix {
          inherit lib;
          rakku = self.nixosConfigurations.rakku.config;
          yari = self.nixosConfigurations.yari.config;
        };
        pkgs.runCommand "pace2-contract" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          cp ${../scripts/pace2-sync-log.py} pace2-sync-log.py
          cp ${../scripts/test_pace2_sync_log.py} test_pace2_sync_log.py
          python3 test_pace2_sync_log.py
          touch $out
        '';
    };
}
