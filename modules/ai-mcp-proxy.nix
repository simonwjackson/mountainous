# Step one deliberately leaves the shared proxy source and derivation unchanged.
{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.media-tsnet-proxy.overrideAttrs (old: {
        pname = "ai-mcp-tsnet-proxy";
        patches = (old.patches or [ ]) ++ [ ../packages/ai-mcp-tsnet-proxy/routing.patch ];
        postPatch = (old.postPatch or "") + ''
          cp ${../packages/ai-mcp-tsnet-proxy/routes.go} routes.go
          cp ${../packages/ai-mcp-tsnet-proxy/routes_test.go} routes_test.go
        '';
        postCheck = (old.postCheck or "") + ''
          go vet ./...
        '';
      });
      system = self.nixosConfigurations.rakku;
      c = system.config;
      extend = modules: (system.extendModules { inherit modules; }).config;
      before = builtins.fromJSON (builtins.readFile ../tests/ai-mcp-proxy-units-before.json);
      services = lib.filterAttrs (name: _: lib.hasPrefix "tsnet-proxy-" name) c.systemd.services;
      # Only the two routed front doors may differ from the before fixture.
      unchanged = lib.subtractLists [
        "tsnet-proxy-ai"
        "tsnet-proxy-ai-staging"
      ] (lib.attrNames before);
      unit = c.systemd.services.tsnet-proxy-ai-staging;
      table = c.environment.etc."tsnet-proxy-ai-staging-mcp.json".source;
      # A tools/callers-only edit must alter the reload trigger, not ExecStart,
      # LoadCredential, restartTriggers, or any other rendered unit setting.
      changed = extend [
        (
          { lib, ... }:
          {
            mountainous.tailnetNames.ai-staging.mcpRoutes.echo.callerNodeIds = lib.mkForce [
              "nAiMcpCheckCallerCNTRL"
            ];
          }
        )
      ];
      changedUnit = changed.systemd.services.tsnet-proxy-ai-staging;
      # An empty caller list, or a node name instead of a stable ID, fails evaluation.
      rejected =
        callers:
        !(builtins.tryEval
          (extend [
            (
              { lib, ... }:
              {
                mountainous.tailnetNames.ai-staging.mcpRoutes.echo.callerNodeIds = lib.mkForce callers;
              }
            )
          ]).environment.etc."tsnet-proxy-ai-staging-mcp.json".source.text
        ).success;
      # Production ai: one row, flakey's stable node ID only, the shared allowlist.
      sparkyTools = import ../lib/openclaw-sparkyfitness-tools.nix;
      prodUnit = c.systemd.services.tsnet-proxy-ai;
      prodText = c.systemd.units."tsnet-proxy-ai.service".text;
      prodTable = c.environment.etc."tsnet-proxy-ai-mcp.json".source;
      prodSecret = c.sops.secrets.sparkyfitness-openclaw-api-key;
      prodBefore = before.tsnet-proxy-ai;
      sharedProxy = self.packages.${pkgs.stdenv.hostPlatform.system}.media-tsnet-proxy;
      # /v1 keeps every flag; only the binary and the table argument change.
      prodExecStart =
        lib.replaceStrings
          [ "${sharedProxy}/bin/" " -port 443 " ]
          [ "${package}/bin/" " -port 443 -mcp-table /etc/tsnet-proxy-ai-mcp.json " ]
          prodBefore.ExecStart;
      lines = text: lib.filter (line: line != "") (lib.splitString "\n" text);
      prodRemoved = lib.subtractLists (lines prodText) (lines prodBefore.text);
      prodAdded = lib.filter (
        line: !(lib.hasPrefix "X-Reload-Triggers=" line) && !(lib.hasPrefix "ExecReload=" line)
      ) (lib.subtractLists (lines prodBefore.text) (lines prodText));
      prodChanged = extend [
        (
          { lib, ... }:
          {
            mountainous.tailnetNames.ai.mcpRoutes.sparkyfitness = {
              callerNodeIds = lib.mkForce [ "nAiMcpCheckCallerCNTRL" ];
              mcpTools = lib.mkForce [ "sparky_get_food_diary" ];
            };
          }
        )
      ];
      prodChangedUnit = prodChanged.systemd.services.tsnet-proxy-ai;
      emptyConfig =
        (system.extendModules {
          modules = [
            (
              { lib, ... }:
              {
                mountainous.tailnetNames.ai-staging.mcpRoutes = lib.mkForce { };
              }
            )
          ];
        }).config;
      emptyUnit = emptyConfig.systemd.services.tsnet-proxy-ai-staging;
      stripReloadTrigger =
        text:
        lib.concatStringsSep "\n" (
          lib.filter (line: !(lib.hasPrefix "X-Reload-Triggers=" line)) (lib.splitString "\n" text)
        );
      # Exercise non-empty credentials too, without creating or reading a secret.
      credentialConfig =
        (system.extendModules {
          modules = [
            {
              mountainous.tailnetNames.ai-staging.mcpRoutes.echo.bearerCredentialFile =
                "/run/secrets/ai-staging-echo-test";
            }
          ];
        }).config;
      rowsValid = lib.all (
        system:
        lib.all (
          name:
          let
            rows = system.config.mountainous.tailnetNames.${name}.mcpRoutes;
            credentials = system.config.systemd.services."tsnet-proxy-${name}".serviceConfig.LoadCredential;
          in
          lib.all (
            tool:
            let
              row = rows.${tool};
            in
            row.callerNodeIds != [ ]
            && row.mcpTools != [ ]
            && (
              row.bearerCredentialFile == null
              || (
                lib.hasPrefix "/run/" row.bearerCredentialFile
                && lib.elem "mcp-${tool}:${row.bearerCredentialFile}" credentials
              )
            )
          ) (lib.attrNames rows)
        ) (lib.attrNames (system.config.mountainous.tailnetNames or { }))
      ) (lib.attrValues self.nixosConfigurations);
    in
    {
      packages.ai-mcp-tsnet-proxy = package;
      checks.ai-mcp-proxy =
        assert rowsValid;
        assert lib.attrNames services == lib.attrNames before;
        assert lib.all (
          name:
          c.systemd.units."${name}.service".text == before.${name}.text
          && services.${name}.serviceConfig.ExecStart == before.${name}.ExecStart
          && services.${name}.restartTriggers == before.${name}.restartTriggers
          && services.${name}.reloadTriggers == before.${name}.reloadTriggers
        ) unchanged;
        assert
          builtins.fromJSON prodTable.text == {
            sparkyfitness = {
              backend = "http://127.0.0.1:3010/mcp";
              # claw-simon (flakey). Laure's claw and every other node get 403.
              callerNodeIds = [ "nbQJZMcewG11CNTRL" ];
              mcpTools = sparkyTools;
              bearerCredential = "mcp-sparkyfitness";
            };
          };
        assert lib.length sparkyTools == 23 && lib.unique sparkyTools == sparkyTools;
        assert
          !(lib.any (tool: lib.elem tool sparkyTools) [
            "sparky_manage_profile"
            "sparky_manage_medications"
            "sparky_manage_progress_photos"
            "sparky_log_food_photo"
            "sparky_get_integrations"
          ]);
        assert !(lib.any (tool: lib.hasInfix "sql" (lib.toLower tool)) sparkyTools);
        assert lib.hasInfix "ai-mcp-tsnet-proxy" prodUnit.serviceConfig.ExecStart;
        assert prodUnit.serviceConfig.ExecStart == prodExecStart;
        assert prodRemoved == [ "ExecStart=${prodBefore.ExecStart}" ];
        assert
          lib.sort builtins.lessThan prodAdded == [
            "ExecStart=${prodExecStart}"
            "LoadCredential=mcp-sparkyfitness:/run/secrets/sparkyfitness-openclaw-api-key"
          ];
        assert prodUnit.serviceConfig.ExecReload == unit.serviceConfig.ExecReload;
        assert prodUnit.restartTriggers == prodBefore.restartTriggers;
        assert prodBefore.reloadTriggers == [ ] && prodUnit.reloadTriggers == [ prodTable ];
        assert prodSecret.sopsFile == ../secrets/hosts/rakku.yaml;
        assert prodSecret.mode == "0400" && prodSecret.owner == null;
        assert prodSecret.restartUnits == [ "tsnet-proxy-ai.service" ];
        assert prodSecret.path == "/run/secrets/sparkyfitness-openclaw-api-key";
        assert prodUnit.serviceConfig == prodChangedUnit.serviceConfig;
        assert prodUnit.restartTriggers == prodChangedUnit.restartTriggers;
        assert prodUnit.reloadTriggers != prodChangedUnit.reloadTriggers;
        assert
          stripReloadTrigger prodText
          == stripReloadTrigger prodChanged.systemd.units."tsnet-proxy-ai.service".text;
        assert lib.attrNames c.mountainous.tailnetNames.ai-staging.mcpRoutes == [ "echo" ];
        assert rejected [ ];
        assert rejected [ "claw-simon" ];
        assert rejected [ "claw-simon.hummingbird-lake.ts.net" ];
        assert rejected [ "flakey" ];
        assert !(rejected [ "nkT3Yhzyy121CNTRL" ]);
        assert lib.hasInfix "ai-mcp-tsnet-proxy" unit.serviceConfig.ExecStart;
        assert lib.hasInfix "-mcp-table /etc/tsnet-proxy-ai-staging-mcp.json" unit.serviceConfig.ExecStart;
        assert lib.hasInfix "-HUP $MAINPID" unit.serviceConfig.ExecReload;
        assert unit.restartTriggers == [ ];
        assert unit.reloadTriggers == [ table ];
        assert unit.serviceConfig.ExecStart == changedUnit.serviceConfig.ExecStart;
        assert unit.serviceConfig.LoadCredential == changedUnit.serviceConfig.LoadCredential;
        assert unit.restartTriggers == changedUnit.restartTriggers;
        assert unit.serviceConfig == emptyUnit.serviceConfig;
        assert unit.restartTriggers == emptyUnit.restartTriggers;
        assert unit.reloadTriggers != emptyUnit.reloadTriggers;
        assert
          stripReloadTrigger c.systemd.units."tsnet-proxy-ai-staging.service".text
          == stripReloadTrigger emptyConfig.systemd.units."tsnet-proxy-ai-staging.service".text;
        assert unit.reloadTriggers != changedUnit.reloadTriggers;
        assert
          stripReloadTrigger c.systemd.units."tsnet-proxy-ai-staging.service".text
          == stripReloadTrigger changed.systemd.units."tsnet-proxy-ai-staging.service".text;
        assert
          (builtins.fromJSON credentialConfig.environment.etc."tsnet-proxy-ai-staging-mcp.json".source.text)
          .echo.bearerCredential == "mcp-echo";
        assert lib.elem "mcp-echo:/run/secrets/ai-staging-echo-test"
          credentialConfig.systemd.services.tsnet-proxy-ai-staging.serviceConfig.LoadCredential;
        pkgs.runCommand "ai-mcp-proxy-boundary" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          test -x ${package}/bin/tsnet-proxy
          python3 ${../tests/ai-mcp-echo.py} ${../packages/ai-mcp-echo.py}
          touch $out
        '';
    };
}
