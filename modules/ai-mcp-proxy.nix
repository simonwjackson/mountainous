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
      # Only the routed front door may differ from the before fixture.
      unchanged = lib.subtractLists [ "tsnet-proxy-ai-staging" ] (lib.attrNames before);
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
        assert c.mountainous.tailnetNames.ai.mcpRoutes == { };
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
