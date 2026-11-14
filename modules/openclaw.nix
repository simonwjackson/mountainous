{ inputs, self, ... }:
{
  mountainous.appProfiles.openclaw = {
    hosts = [ "yari" ];
    package =
      system:
      import ../lib/openclaw-package.nix {
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        inherit inputs;
      };
    activation = _: ''
      set -euo pipefail
      control=$(readlink -e /run/current-system/sw/bin/openclaw-profile-control)
      /run/wrappers/bin/sudo -n "$control" restart-and-check
    '';
  };
  nixos.modules.base =
    { config, lib, ... }:
    {
      mountainous.appUpdates.openclaw = lib.mkIf (config.networking.hostName == "unzen") {
        input = "nix-openclaw";
        hosts = [ "yari" ];
        schedule = "Sun *-*-* 02:15:00 America/Denver";
        gateFile = "/var/lib/app-updater/enabled-openclaw";
        sourceBranch = "cairn";
        # Finish or abort by 06:15, before the 07:00 morning brief.
        timeout = "4h";
        # A late catch-up could overlap the brief despite the job timeout.
        persistent = false;
        checks = [
          "openclaw"
          "openclaw-config"
        ];
      };
    };
  nixos.modules.openclaw =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      profilePath = config.mountainous.appProfiles.openclaw.profilePath;
      people = import ../lib/openclaw-instances.nix { inherit legacyEnabled; };
      legacyEnabled = config.mountainous.features.openclaw.legacy.enable;
      sharedBindMounts = {
        # Bind the directory, not the symlink target: deploy-rs atomically
        # replaces links here while the container remains running.
        "/nix/var/nix/profiles/apps" = {
          hostPath = "/nix/var/nix/profiles/apps";
          isReadOnly = true;
        };
        "/run/host-credentials/front-door" = {
          hostPath = config.sops.secrets.ai-gateway-key-openclaw-yari.path;
          isReadOnly = true;
        };
        "/run/host-credentials/gateway-token" = {
          hostPath = config.sops.secrets.openclaw-gateway-token.path;
          isReadOnly = true;
        };
        "/run/host-credentials/oauth-secret" = {
          hostPath = config.sops.secrets.tailscale-oauth-secret.path;
          isReadOnly = true;
        };
      };

      newNames = map (name: people.${name}.containerName) (lib.attrNames people);
      # Frozen deployed artifacts are real closure dependencies, not untracked
      # absolute strings. Copy them from Yari before evaluating this placement.
      frozenStorePath = path: builtins.appendContext path { ${path}.path = true; };
      legacySystem = frozenStorePath "/nix/store/j5gwnqw7sw5gbs5fbr19dmvrrvalj335-nixos-system-claw-26.11pre-git";
      legacyConf = frozenStorePath "/nix/store/30qbz85w5qhckyl8dmj9m294ifyv7f07-etc-nixos-containers-openclaw.conf";
      legacyTriggers = frozenStorePath "/nix/store/n63mxcv1saygx0b0ypkd01cl6h02nknh-X-Restart-Triggers-container-openclaw";
      idleCheck = pkgs.writeScriptBin "openclaw-wait-idle" (
        "#!${pkgs.python3}/bin/python3\n" + builtins.readFile ../scripts/openclaw-wait-idle.py
      );
      controller = pkgs.writeShellApplication {
        name = "openclaw-profile-control";
        runtimeInputs = [
          pkgs.nixos-container
          pkgs.systemd
          pkgs.coreutils
          idleCheck
        ];
        text = ''
          if [[ $# != 1 || "$1" != restart-and-check ]]; then exit 2; fi
          # Never touch the live legacy gateway during the split. Both new
          # placements resolve this ONE app profile at process startup.
          for container in ${lib.concatStringsSep " " newNames}; do
            systemctl is-active --quiet "container@$container.service"
            openclaw-wait-idle "$container"
            nixos-container run "$container" -- systemctl restart openclaw-gateway.service
            ready() {
              nixos-container run "$container" -- systemctl is-active --quiet openclaw-gateway.service &&
              nixos-container run "$container" -- ${pkgs.curl}/bin/curl -fsS --max-time 5 http://127.0.0.1:18789/healthz |
                ${pkgs.jq}/bin/jq -e '.ok == true' >/dev/null &&
              [[ "$(nixos-container run "$container" -- ${pkgs.curl}/bin/curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:18789/)" == 200 ]]
            }
            deadline=$((SECONDS + 120))
            until ready; do
              if (( SECONDS >= deadline )); then echo "$container failed health gate" >&2; exit 1; fi
              sleep 2
            done
            incarnation=$(nixos-container run "$container" -- systemctl show openclaw-gateway -p MainPID -p InvocationID -p NRestarts)
            for ((i = 0; i < 5; i++)); do
              sleep 1
              ready
              [[ "$(nixos-container run "$container" -- systemctl show openclaw-gateway -p MainPID -p InvocationID -p NRestarts)" == "$incarnation" ]]
            done
            # Sources also run the shared package; restart after its health gate.
            nixos-container run "$container" -- systemctl try-restart openclaw-session-share.service
          done
        '';
      };
    in
    {
      options.mountainous.features.openclaw = {
        enable = lib.mkEnableOption "isolated per-person OpenClaw gateways" // {
          default = true;
        };
        legacy.enable = lib.mkEnableOption "frozen legacy gateway until Laure's approved final handoff" // {
          default = true;
        };
      };
      config = lib.mkIf config.mountainous.features.openclaw.enable {
        system.extraDependencies = [
          legacySystem
          legacyConf
          legacyTriggers
        ];
        environment.systemPackages = [
          controller
          idleCheck
        ];
        security.sudo.extraRules = [
          {
            users = [ "app-deploy" ];
            runAs = "root";
            commands = [
              {
                command = "${controller}/bin/openclaw-profile-control restart-and-check";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];
        sops.secrets = {
          ai-gateway-key-openclaw-yari = {
            sopsFile = ../secrets/hosts/yari.yaml;
            mode = "0400";
            restartUnits =
              (lib.optional legacyEnabled "container@openclaw.service")
              ++ map (name: "container@${name}.service") newNames;
          };
          openclaw-gateway-token = {
            sopsFile = ../secrets/hosts/yari.yaml;
            mode = "0400";
            restartUnits =
              (lib.optional legacyEnabled "container@openclaw.service")
              ++ map (name: "container@${name}.service") newNames;
          };
        };
        containers =
          (lib.optionalAttrs legacyEnabled {
            openclaw = {
              autoStart = true;
              enableTun = true;
              privateNetwork = true;
              hostAddress = "10.231.0.1";
              localAddress = "10.231.0.2";
              bindMounts = sharedBindMounts;
              # Frozen until Laure's final handoff. Pinning the system path keeps
              # the nspawn unit/restart triggers/config byte-identical even as the
              # shared definition and skills evolve for the new placements.
              path = lib.mkForce legacySystem;
            };
          })
          // lib.mapAttrs' (
            name: person:
            lib.nameValuePair person.containerName {
              autoStart = true;
              enableTun = true;
              privateNetwork = true;
              hostAddress =
                if name == "simon" then
                  "10.231.1.1"
                else if legacyEnabled then
                  "10.231.2.1"
                else
                  "10.231.0.1";
              localAddress =
                if name == "simon" then
                  "10.231.1.2"
                else if legacyEnabled then
                  "10.231.2.2"
                else
                  "10.231.0.2";
              bindMounts = sharedBindMounts;
              config = import ../lib/openclaw-container.nix { inherit inputs profilePath person; };
            }
          ) people;
        systemd.services =
          lib.mapAttrs' (
            _: person:
            lib.nameValuePair "container@${person.containerName}" {
              after = [ "sops-install-secrets.service" ];
              # Reload runs switch-to-configuration inside the running container:
              # only its changed units restart, never the whole container. nspawn
              # settings (bind mounts, addresses) wait for a deliberate restart.
              reloadIfChanged = person.reloadContainerInPlace or false;
              serviceConfig = {
                MemoryMax = "8G";
                TimeoutStopSec = 180;
              };
              unitConfig.RequiresMountsFor = [ "/var/lib/nixos-containers/${person.containerName}" ];
            }
          ) people
          // lib.optionalAttrs legacyEnabled {
            "container@openclaw" = {
              after = [ "sops-install-secrets.service" ];
              serviceConfig = {
                MemoryMax = "8G";
                TimeoutStopSec = 180;
              };
              unitConfig.RequiresMountsFor = [ "/var/lib/nixos-containers/openclaw" ];
              unitConfig."X-Restart-Triggers" = lib.mkForce legacyTriggers;
            };
          };
        # Preserve the actual historical artifacts, not merely their text:
        # changing a derivation's string context also changes restart triggers.
        environment.etc."nixos-containers/openclaw.conf".source = lib.mkIf legacyEnabled (
          lib.mkForce legacyConf
        );
        networking.nat = {
          enable = true;
          internalInterfaces =
            (lib.optional legacyEnabled "ve-openclaw") ++ map (name: "ve-${name}") newNames;
          externalInterface = "enp0s6";
        };
        # Retain the whole nspawn root: overlay identity, config, and service state.
        environment.persistence."/permafrost".directories = lib.unique (
          [ "/var/lib/nixos-containers/openclaw" ] ++ map (name: "/var/lib/nixos-containers/${name}") newNames
        );
        assertions = [
          {
            assertion = config.networking.hostName == "yari";
            message = "OpenClaw trial placement is Yari only.";
          }
        ];
      };
    };
  perSystem =
    { pkgs, lib, ... }:
    let
      host = self.nixosConfigurations.yari.config;
      productionHost =
        (self.nixosConfigurations.yari.extendModules {
          modules = [
            (
              { lib, ... }:
              {
                mountainous.features.openclaw.legacy.enable = lib.mkForce false;
              }
            )
          ];
        }).config;
      container = host.containers.claw-simon;
      c = container.config;
      gateway = c.services.openclaw-gateway;
      laure = host.containers.openclaw.config.services.openclaw-gateway.config;
      unit = c.systemd.services.openclaw-gateway.serviceConfig;
      firewall = c.networking.nftables.tables.openclaw-egress.content;
      key = lib.findFirst (
        k: k.name == "openclaw@yari"
      ) null self.nixosConfigurations.rakku.config.mountainous.features.ai-gateway.settings.gateway_keys;
      # The rows that admit flakey (lib/ai-mcp-rows.nix): its own and the shared.
      simonRows = lib.filterAttrs (_: spec: lib.elem "flakey" spec.callers) (
        import ../lib/ai-mcp-rows.nix
      );
    in
    {
      checks = {
        openclaw-people =
          assert import ../tests/openclaw-people.nix { inherit lib host; };
          pkgs.runCommand "openclaw-people-drift" { } "touch $out";
        openclaw-in-place =
          assert
            toString productionHost.environment.etc."nixos-containers/openclaw.conf".source
            != "/nix/store/30qbz85w5qhckyl8dmj9m294ifyv7f07-etc-nixos-containers-openclaw.conf";
          assert
            toString productionHost.containers.openclaw.path
            == toString productionHost.containers.openclaw.config.system.build.toplevel;
          assert import ../tests/openclaw-people.nix {
            inherit lib;
            host = productionHost;
          };
          pkgs.runCommand "openclaw-in-place-drift" { } "touch $out";
        openclaw =
          assert import ../tests/openclaw-mail-filing.nix { inherit lib host; };
          assert import ../tests/openclaw-wind-down.nix {
            inherit lib;
            host = productionHost;
          };
          assert import ../tests/openclaw-people.nix { inherit lib host; };
          assert import ../tests/openclaw-people.nix {
            inherit lib;
            host = productionHost;
          };
          assert
            self.deploy.nodes.yari.profiles.openclaw.profilePath == "/nix/var/nix/profiles/apps/openclaw";
          assert !(self.deploy.nodes.rakku.profiles ? openclaw);
          assert host.mountainous.appProfiles.openclaw.enable;
          assert
            !self.nixosConfigurations.unzen.config.systemd.timers.app-update-openclaw.timerConfig.Persistent;
          assert
            self.nixosConfigurations.unzen.config.systemd.services.app-update-openclaw.serviceConfig.TimeoutStartSec
            == "4h";
          assert container.bindMounts."/nix/var/nix/profiles/apps".isReadOnly;
          assert
            self.nixosConfigurations.unzen.config.mountainous.appUpdates.openclaw.checks == [
              "openclaw"
              "openclaw-config"
            ];
          assert import ../tests/openclaw-morning-brief.nix {
            inherit lib;
            container = c;
          };
          assert c.networking.nameservers == [ "127.0.0.1" ];
          assert c.services.dnsmasq.settings.listen-address == [ "127.0.0.1" ];
          assert container.privateNetwork && container.enableTun && container.autoStart;
          assert gateway.config.gateway.bind == "loopback";
          assert
            gateway.config.gateway.auth.mode == "trusted-proxy" && !gateway.config.gateway.auth.allowTailscale;
          assert gateway.config.gateway.auth.trustedProxy.userHeader == "tailscale-user-login";
          assert lib.elem "/run/tailscale" unit.InaccessiblePaths;
          assert lib.hasInfix "--https=443 http://127.0.0.1:18788" c.systemd.services.claw-tailnet.script;
          assert lib.hasInfix "-tag tag:mountainous -login simon.jackson@gmail.com"
            c.systemd.services.claw-identity-proxy.serviceConfig.ExecStart;
          assert c.systemd.services.claw-identity-proxy.serviceConfig.DynamicUser;
          assert
            gateway.config.models.providers.front-door.baseUrl == "https://ai.hummingbird-lake.ts.net/v1";
          assert gateway.config.agents.defaults.model.primary == "front-door/claude-opus-5-5";
          assert lib.all (name: (gateway.config.models.providers.${name}.timeoutSeconds or null) == 600) [
            "front-door"
            "openai"
          ];
          assert gateway.config.agents.ownership == "explicit";
          assert gateway.config.agents.defaults.systemAgent.agentId == "main";
          assert gateway.config.agents.entries.main.workspace == gateway.config.agents.defaults.workspace;
          assert gateway.config.agents.entries.main.heartbeat.every == "30m";
          assert (gateway.config.mcp.sessionIdleTtlMs or null) == 600000;
          assert gateway.config.mcp.apps.enabled;
          # The tailnet node is flakey; the container and its state stay claw-simon.
          assert gateway.config.mcp.apps.sandboxOrigin == "https://flakey.hummingbird-lake.ts.net:8443";
          assert gateway.config.gateway.publicOrigin == "https://flakey.hummingbird-lake.ts.net";
          assert
            gateway.config.gateway.controlUi.allowedOrigins == [ "https://flakey.hummingbird-lake.ts.net" ];
          assert lib.hasInfix "--hostname=flakey " c.systemd.services.claw-tailnet.script;
          assert c.networking.hostName == "flakey";
          assert lib.hasInfix "--host flakey.hummingbird-lake.ts.net "
            host.containers.openclaw.config.systemd.services.openclaw-session-share.script;
          # Laure's node is snowy (claw until the in-place rename); her container
          # and its state stay openclaw. flakey's Session Share source follows.
          assert lib.hasInfix "--host snowy.hummingbird-lake.ts.net "
            c.systemd.services.openclaw-session-share.script;
          assert host.containers.openclaw.config.networking.hostName == "snowy";
          assert lib.hasInfix "--hostname=snowy "
            host.containers.openclaw.config.systemd.services.claw-tailnet.script;
          assert laure.gateway.publicOrigin == "https://snowy.hummingbird-lake.ts.net";
          assert laure.gateway.controlUi.allowedOrigins == [ "https://snowy.hummingbird-lake.ts.net" ];
          assert laure.mcp.apps.sandboxOrigin == "https://snowy.hummingbird-lake.ts.net:8443";
          assert
            laure.gateway.trustedProxies == [
              "127.0.0.1"
              "::1"
            ];
          assert !(lib.hasInfix "claw.hummingbird-lake.ts.net" (builtins.toJSON laure));
          assert !(lib.hasInfix "claw-simon" (builtins.toJSON gateway.config));
          assert lib.hasInfix "--advertise-tags=tag:claw" c.systemd.services.claw-tailnet.script;
          assert c.systemd.services.claw-tailnet.serviceConfig.User == "tailscale";
          assert gateway.config.plugins.enabled;
          assert
            gateway.config.plugins.allow == [
              "browser"
              "memory-core"
              "openai"
              "web-readability"
              "session-share"
            ];
          assert gateway.config.tools.profile == "full";
          assert
            gateway.config.tools.deny == [
              "group:runtime"
              "web_search"
            ];
          assert gateway.config.tools.sessions.visibility == "agent";
          assert
            gateway.config.tools.agentToAgent == {
              enabled = true;
              allow = [
                "main"
                "mail"
              ];
            };
          assert
            gateway.config.tools.allow == [
              "ask_user"
              "group:memory"
              "group:fs"
              "group:web"
              "cron"
              "heartbeat_respond"
              "progress_card"
              "group:sessions"
              "agents_list"
              "browser"
              "view_image"
              "image_generate"
              "bundle-mcp"
              "claw-scryer-simon__scryer_search"
              "claw-scryer-simon__scryer_title"
              "claw-scryer-simon__scryer_add"
              "claw-scryer-simon__scryer_monitor"
              "show_widget"
              "claw-ebay-simon__ebay_search"
              "claw-ebay-simon__ebay_listings"
              "claw-ebay-simon__ebay_drafts"
              "claw-ebay-simon__ebay_messages"
              "claw-ebay-simon__ebay_offers"
              "claw-ebay-simon__ebay_draft_price"
              "claw-ebay-simon__ebay_draft_reply"
              "claw-ebay-simon__ebay_draft_offer"
              "claw-ebay-simon__ebay_draft_listing"
              "claw-ebay-simon__ebay_apply_draft"
              "claw-ebay-simon__ebay_skip_draft"
              "claw-ebay-simon__ebay_save_draft"
              "claw-ebay-simon__ebay_put_back_price"
              "claw-ebay-simon__ebay_upload_photo"
              "claw-gmail__mail_list"
              "claw-gmail__mail_read"
              "claw-gmail__mail_not_mine"
              "claw-gmail__mail_label"
              "claw-gmail__mail_archive"
              "claw-gmail__mail_draft"
              "claw-gmail__mail_discard_draft"
              "claw-family-calendar-simon__family_calendar_events"
              "claw-family-calendar-simon__family_calendar_add"
              "claw-family-calendar-simon__family_calendar_remove"
            ]
            ++ map (tool: "sparkyfitness__${tool}") (import ../lib/openclaw-sparkyfitness-tools.nix);
          # No key, header or environment: the front door's caller lock and its
          # server-held key are the only authentication.
          assert
            gateway.config.mcp.servers.sparkyfitness == {
              transport = "streamable-http";
              url = "https://ai.hummingbird-lake.ts.net/mcp/sparkyfitness";
              toolFilter.include = import ../lib/openclaw-sparkyfitness-tools.nix;
            };
          assert !(lib.hasInfix "sparkyfitness-openclaw-api-key" (builtins.toJSON gateway.config));
          assert lib.pathExists
            "${builtins.elemAt gateway.config.skills.load.extraDirs 1}/nutrition-fitness/SKILL.md";
          assert !(laure.mcp.servers ? sparkyfitness);
          assert !(lib.any (tool: lib.hasPrefix "sparkyfitness__" tool) laure.tools.allow);
          assert
            !(lib.pathExists "${builtins.elemAt laure.skills.load.extraDirs 1}/nutrition-fitness/SKILL.md");
          assert
            gateway.config.mcp.servers.claw-family-calendar-simon.toolFilter.include
            == (import ../lib/ai-mcp-rows.nix).family-calendar.tools;
          assert
            gateway.config.mcp.servers.claw-family-calendar-simon.codex.defaultToolsApprovalMode == "approve";
          assert lib.pathExists
            "${builtins.elemAt gateway.config.skills.load.extraDirs 1}/family-calendar/SKILL.md";
          assert !(gateway.config.mcp.servers ? claw-scryer);
          assert
            gateway.config.mcp.servers.claw-scryer-simon.toolFilter.include == [
              "scryer_graphql"
              "scryer_search"
              "scryer_title"
              "scryer_add"
              "scryer_monitor"
            ];
          assert !(gateway.config.mcp.servers.claw-scryer-simon ? codex);
          # Simon's own tools (stage 5) and the shared ones (stage 7): each keeps
          # its server name and reaches its row on the production front door.
          # No key, header or environment.
          assert lib.all (
            row:
            let
              spec = simonRows.${row};
              server = gateway.config.mcp.servers.${spec.server};
            in
            builtins.removeAttrs server [ "codex" ] == {
              transport = "streamable-http";
              url = "https://ai.hummingbird-lake.ts.net/mcp/${row}";
              toolFilter.include = spec.tools;
            }
          ) (lib.attrNames simonRows);
          assert
            lib.attrNames (
              lib.filterAttrs (_: s: lib.hasPrefix "https://ai." (s.url or "")) gateway.config.mcp.servers
            ) == lib.sort builtins.lessThan (lib.mapAttrsToList (_: spec: spec.server) simonRows);
          assert gateway.config.mcp.servers.claw-ebay-simon.codex.defaultToolsApprovalMode == "approve";
          # Stage 7: Laure's servers and the shared ones keep their names and
          # reach their rows; no server of either gateway uses a per-tool node.
          assert
            laure.mcp.servers.claw-scryer-laure == {
              transport = "streamable-http";
              url = "https://ai.hummingbird-lake.ts.net/mcp/scryer-laure";
              toolFilter.include = import ../lib/openclaw-scryer-tools.nix;
            };
          assert
            laure.mcp.servers.claw-family-calendar == {
              transport = "streamable-http";
              url = "https://ai.hummingbird-lake.ts.net/mcp/family-calendar-laure";
              toolFilter.include = [ "family_calendar_events" ];
            };
          assert lib.all
            (
              servers:
              servers.claw-maps == {
                transport = "streamable-http";
                url = "https://ai.hummingbird-lake.ts.net/mcp/maps";
                toolFilter.include = [ "travel_time" ];
              }
              &&
                servers.claw-websearch == {
                  transport = "streamable-http";
                  url = "https://ai.hummingbird-lake.ts.net/mcp/websearch";
                  toolFilter.include = [ "web_search" ];
                }
            )
            [
              gateway.config.mcp.servers
              laure.mcp.servers
            ];
          assert lib.all (s: !(s ? url) || lib.hasPrefix "https://ai.hummingbird-lake.ts.net/mcp/" s.url) (
            lib.attrValues gateway.config.mcp.servers ++ lib.attrValues laure.mcp.servers
          );
          assert !(lib.hasInfix "ai-gateway-key" (builtins.toJSON laure.mcp));
          assert !(lib.hasInfix "scryer-password" (builtins.toJSON laure.mcp));
          assert lib.all (a: !(lib.any (d: lib.hasPrefix "claw-websearch" d) (a.tools.deny or [ ]))) (
            lib.attrValues gateway.config.agents.entries
          );
          assert
            lib.length gateway.config.skills.load.extraDirs == 2
            && lib.pathExists "${lib.head gateway.config.skills.load.extraDirs}/scryer/SKILL.md";
          assert lib.pathExists "${lib.head gateway.config.skills.load.extraDirs}/research/SKILL.md";
          assert lib.pathExists
            "${builtins.elemAt gateway.config.skills.load.extraDirs 1}/wind-down/SKILL.md";
          assert (gateway.config.agents.defaults.subagents.maxChildrenPerAgent or null) == 8;
          assert lib.hasInfix "tell the user the exact error text" (
            builtins.readFile ../lib/openclaw-skills/shared/research/SKILL.md
          );
          assert lib.hasInfix "research inline, one angle at a time" (
            builtins.readFile ../lib/openclaw-skills/shared/research/SKILL.md
          );
          assert lib.hasInfix "call `sessions_yield` directly" (
            builtins.readFile ../lib/openclaw-skills/shared/research/SKILL.md
          );
          assert
            !lib.hasInfix ''id: "sessions_yield"'' (
              builtins.readFile ../lib/openclaw-skills/shared/research/SKILL.md
            );
          assert !gateway.config.tools.codeMode.enabled && gateway.config.tools.fs.workspaceOnly;
          assert host.systemd.services."container@claw-simon".serviceConfig.MemoryMax == "8G";
          # A changed container switches in place, Laure's and flakey's alike.
          assert lib.all
            (
              name:
              host.systemd.services."container@${name}".reloadIfChanged
              && lib.hasInfix "X-ReloadIfChanged=true" host.systemd.units."container@${name}.service".text
            )
            [
              "openclaw"
              "claw-simon"
            ];
          # Stop limits. The gateway's limit funds one full ordinary stop. The
          # host's limit outlasts it plus one more guest unit at systemd's 90 s.
          assert unit.KillMode == "mixed" && unit.TimeoutStopSec == 35;
          assert
            host.systemd.services."container@claw-simon".serviceConfig.TimeoutStopSec
            >= unit.TimeoutStopSec + 90;
          assert !gateway.config.tools.elevated.enabled;
          assert gateway.config.browser.enabled && gateway.config.browser.headless;
          assert gateway.config.browser.ssrfPolicy.dangerouslyAllowPrivateNetwork;
          assert gateway.config.agents.defaults.thinkingDefault == "medium";
          assert lib.all (
            m: m ? contextWindow && m ? maxTokens && m.contextWindow > 0 && m.maxTokens > 0
          ) gateway.config.models.providers.front-door.models;
          assert
            (lib.findFirst (
              m: m.id == "claude-opus-5-5"
            ) null gateway.config.models.providers.front-door.models).contextWindow == 1000000;
          assert
            !(
              lib.findFirst (m: m.id == "claude-opus-5-5") null gateway.config.models.providers.front-door.models
              ? contextTokens
            );
          assert
            (lib.findFirst (m: m.id == "gpt-6.1-sol") null gateway.config.models.providers.front-door.models)
            .contextTokens == 272000;
          assert lib.all (
            m:
            m.reasoning
            &&
              m.input == [
                "text"
                "image"
              ]
          ) gateway.config.models.providers.front-door.models;
          assert gateway.config.agents.defaults.mediaModels.image.primary == "openai/gemini-3.1-flash-image";
          assert !(gateway.config.mcp.servers ? system-monitor);
          assert c.environment.etc."openclaw/openclaw.json".mode == "0600";
          assert lib.elem "/nix/var/nix/daemon-socket" unit.InaccessiblePaths;
          assert lib.hasInfix "--exit-node=100.88.212.117" c.systemd.services.claw-tailnet.script;
          assert lib.hasInfix "--exit-node-allow-lan-access=false" c.systemd.services.claw-tailnet.script;
          assert
            lib.hasInfix "policy drop;" firewall && lib.hasInfix "oifname \"tailscale0\" accept" firewall;
          assert lib.hasInfix "meta skuid 991 accept" firewall;
          assert c.users.users.openclaw.uid != c.users.users.tailscale.uid;
          assert c.systemd.services.tailscaled.serviceConfig.User == "tailscale";
          assert
            unit.ProtectSystem == "strict" && unit.ProtectHome && unit.NoNewPrivileges && unit.PrivateTmp;
          assert unit.ReadWritePaths == [ "/var/lib/openclaw" ] && unit.MemoryMax == "8G";
          assert unit.TasksMax == 2048;
          assert
            gateway.config.skills.allowBundled == [
              "weather"
              "visualize"
              "diagram-maker"
            ];
          assert !(gateway.config ? channels);
          assert host.networking.firewall.allowedTCPPorts == [ ];
          assert
            key.models == [
              "claude-opus-5-5"
              "gpt-6.1-sol"
              "gemini-3.8-flash-high"
              "gemini-3.1-flash-image"
              "gpt-image-2"
            ];
          assert
            key.dialects == [
              "chat_completions"
              "responses"
              "models"
              "images"
            ];
          assert key.monthly_cap_usd == 1000000000 && key.requests_per_minute == 300;
          pkgs.runCommand "openclaw-isolation" {
            # Builds the identity proxy for this system and runs its tests.
            proxy = import ../lib/claw-identity-proxy.nix { inherit pkgs; };
          } "touch $out";
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isAarch64 {
        openclaw-in-place-config =
          pkgs.runCommand "openclaw-in-place-config"
            {
              nativeBuildInputs = [
                pkgs.jq
                pkgs.gnused
              ];
            }
            ''
              system=$(sed -n 's/^SYSTEM_PATH=//p' ${productionHost.system.build.toplevel}/etc/nixos-containers/openclaw.conf)
              test "$system" = ${productionHost.containers.openclaw.config.system.build.toplevel}
              test "$system" != /nix/store/j5gwnqw7sw5gbs5fbr19dmvrrvalj335-nixos-system-claw-26.11pre-git
              export HOME=$TMPDIR OPENCLAW_STATE_DIR=$TMPDIR/state
              export OPENCLAW_CONFIG_PATH="$system/etc/openclaw/openclaw.json"
              export FRONT_DOOR_API_KEY=test-only OPENCLAW_GATEWAY_PASSWORD=test-only
              jq -e '.gateway.publicOrigin == "https://snowy.hummingbird-lake.ts.net" and .gateway.auth.trustedProxy.allowUsers == ["chancerellelaure@gmail.com"] and .gateway.roles.default == "laure" and (.gateway.roles.definitions | keys) == ["laure"] and (.agents.entries | keys) == ["laure"] and .agents.defaults.workspace == "/var/lib/openclaw/workspace-laure" and (.mcp.servers | keys) == ["claw-family-calendar","claw-maps","claw-scryer-laure","claw-websearch"] and .plugins.entries["session-share"].enabled' "$OPENCLAW_CONFIG_PATH"
              ${gateway.package}/bin/openclaw config validate
              touch $out
            '';
        openclaw-config = pkgs.runCommand "openclaw-config" { } ''
          grep -F "/nix/var/nix/profiles/apps/openclaw/bin/openclaw gateway" ${gateway.execStart}
          export HOME=$TMPDIR
          export OPENCLAW_STATE_DIR=$TMPDIR/state
          export OPENCLAW_CONFIG_PATH=${c.environment.etc."openclaw/openclaw.json".source}
          export FRONT_DOOR_API_KEY=test-only
          export OPENCLAW_GATEWAY_PASSWORD=test-only
          ${gateway.package}/bin/openclaw config validate
          ${lib.concatMapStringsSep "\n"
            (
              name:
              let
                new = host.containers.${name}.config;
              in
              "export OPENCLAW_CONFIG_PATH=${
                new.environment.etc."openclaw/openclaw.json".source
              }\n${new.services.openclaw-gateway.package}/bin/openclaw config validate"
            )
            (
              map (p: p.containerName) (
                lib.attrValues (
                  import ../lib/openclaw-instances.nix {
                    legacyEnabled = host.mountainous.features.openclaw.legacy.enable;
                  }
                )
              )
            )
          }
          touch $out
        '';
      };
    };
}
