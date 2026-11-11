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
      controller = pkgs.writeShellApplication {
        name = "openclaw-profile-control";
        runtimeInputs = [
          pkgs.nixos-container
          pkgs.systemd
          pkgs.coreutils
        ];
        text = ''
          if [[ $# != 1 || "$1" != restart-and-check ]]; then exit 2; fi
          systemctl is-active --quiet container@openclaw.service
          nixos-container run openclaw -- systemctl restart openclaw-gateway.service
          ready() {
            nixos-container run openclaw -- systemctl is-active --quiet openclaw-gateway.service &&
            nixos-container run openclaw -- ${pkgs.curl}/bin/curl -fsS --max-time 5 http://127.0.0.1:18789/healthz |
              ${pkgs.jq}/bin/jq -e '.ok == true' >/dev/null &&
            [[ "$(nixos-container run openclaw -- ${pkgs.curl}/bin/curl -sS --max-time 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:18789/)" == 200 ]]
          }
          deadline=$((SECONDS + 120))
          until ready; do
            if (( SECONDS >= deadline )); then echo 'OpenClaw profile failed health gate' >&2; exit 1; fi
            sleep 2
          done
          incarnation=$(nixos-container run openclaw -- systemctl show openclaw-gateway -p MainPID -p InvocationID -p NRestarts)
          for ((i = 0; i < 5; i++)); do
            sleep 1
            ready
            [[ "$(nixos-container run openclaw -- systemctl show openclaw-gateway -p MainPID -p InvocationID -p NRestarts)" == "$incarnation" ]]
          done
        '';
      };
    in
    {
      options.mountainous.features.openclaw.enable = lib.mkEnableOption "isolated OpenClaw trial" // {
        default = true;
      };
      config = lib.mkIf config.mountainous.features.openclaw.enable {
        environment.systemPackages = [ controller ];
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
            restartUnits = [ "container@openclaw.service" ];
          };
          openclaw-gateway-token = {
            sopsFile = ../secrets/hosts/yari.yaml;
            mode = "0400";
            restartUnits = [ "container@openclaw.service" ];
          };
        };
        containers.openclaw = {
          autoStart = true;
          enableTun = true;
          privateNetwork = true;
          hostAddress = "10.231.0.1";
          localAddress = "10.231.0.2";
          bindMounts = {
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
          config = import ../lib/openclaw-container.nix { inherit inputs profilePath; };
        };
        networking.nat = {
          enable = true;
          internalInterfaces = [ "ve-openclaw" ];
          externalInterface = "enp0s6";
        };
        # Retain the whole nspawn root: overlay identity, config, and service state.
        environment.persistence."/permafrost".directories = [ "/var/lib/nixos-containers/openclaw" ];
        systemd.services."container@openclaw" = {
          after = [ "sops-install-secrets.service" ];
          serviceConfig = {
            MemoryMax = "8G";
            # Longer than the container needs to stop itself: the gateway's
            # 35 s, then one more unit at its 90 s default, then 55 s spare.
            # When the host kills a container that is still stopping, nspawn
            # leaves a mount behind, the next start fails once, and a system
            # switch returns exit 4.
            TimeoutStopSec = 180;
          };
          unitConfig.RequiresMountsFor = [ "/var/lib/nixos-containers/openclaw" ];
        };
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
      container = host.containers.openclaw;
      c = container.config;
      gateway = c.services.openclaw-gateway;
      unit = c.systemd.services.openclaw-gateway.serviceConfig;
      firewall = c.networking.nftables.tables.openclaw-egress.content;
      key = lib.findFirst (
        k: k.name == "openclaw@yari"
      ) null self.nixosConfigurations.rakku.config.mountainous.features.ai-gateway.settings.gateway_keys;
    in
    {
      checks = {
        openclaw =
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
          assert
            gateway.config.gateway.auth.trustedProxy.allowUsers == [
              "simon.jackson@gmail.com"
              "chancerellelaure@gmail.com"
            ];
          assert gateway.config.gateway.roles.default == "pending";
          assert gateway.config.gateway.roles.definitions.pending.scopes == [ ];
          assert gateway.config.gateway.roles.definitions.simon.agents == [ "main" ];
          assert gateway.config.gateway.roles.definitions.laure.agents == [ "laure" ];
          assert lib.all (name: gateway.config.gateway.roles.definitions.${name}.sessions.others == "write") [
            "simon"
            "laure"
          ];
          assert lib.all
            (
              name:
              gateway.config.gateway.roles.definitions.${name}.scopes == [
                "operator.read"
                "operator.write"
                "operator.approvals"
                "operator.questions"
              ]
            )
            [
              "simon"
              "laure"
            ];
          assert lib.all (r: !(lib.elem "operator.admin" r.scopes)) (
            lib.attrValues gateway.config.gateway.roles.definitions
          );
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
          # Two agents; both keep a heartbeat (any per-agent block disables the rest).
          assert
            lib.attrNames gateway.config.agents.entries == [
              "laure"
              "main"
            ];
          assert
            gateway.config.agents.entries.laure.identity == {
              name = "Snowy";
              emoji = "❄️";
              theme = "Calm and clear-headed, a bit dry, and quietly on top of things.";
              avatar = "avatars/avatar.png";
            };
          assert gateway.config.agents.ownership == "explicit";
          assert gateway.config.agents.defaults.systemAgent.agentId == "main";
          assert gateway.config.agents.entries.main.workspace == gateway.config.agents.defaults.workspace;
          assert lib.all (a: a.heartbeat.every == "30m") (lib.attrValues gateway.config.agents.entries);
          assert
            gateway.config.agents.entries.main.tools.deny == [
              "claw-family-calendar__*"
              "claw-scryer-laure__*"
            ];
          assert
            gateway.config.agents.entries.laure.tools.deny == [
              "claw-calendar__*"
              "claw-scryer-simon__*"
              "basic-react__*"
              "budget-allocator__*"
              "system-monitor__*"
            ];
          assert
            gateway.config.mcp.servers.claw-family-calendar.toolFilter.include == [
              "family_calendar_events"
            ];
          assert lib.all
            (
              name:
              let
                server = gateway.config.mcp.servers.${name};
              in
              server.args == [ "--stdio" ]
              && lib.hasSuffix "/bin/mcp-server-${name}" server.command
              && !(server ? url)
            )
            [
              "basic-react"
              "budget-allocator"
            ];
          assert (gateway.config.mcp.sessionIdleTtlMs or null) == 600000;
          assert gateway.config.mcp.apps.enabled;
          assert gateway.config.mcp.apps.sandboxOrigin == "https://claw.hummingbird-lake.ts.net:8443";
          assert lib.hasInfix "--advertise-tags=tag:claw" c.systemd.services.claw-tailnet.script;
          assert c.systemd.services.claw-tailnet.serviceConfig.User == "tailscale";
          assert gateway.config.plugins.enabled;
          assert
            gateway.config.plugins.allow == [
              "browser"
              "memory-core"
              "openai"
              "web-readability"
            ];
          assert gateway.config.tools.profile == "full";
          assert gateway.config.tools.deny == [ "group:runtime" ];
          assert gateway.config.tools.sessions.visibility == "agent";
          assert !gateway.config.tools.agentToAgent.enabled;
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
              "claw-scryer-laure__scryer_search"
              "claw-scryer-laure__scryer_title"
              "claw-scryer-laure__scryer_add"
              "claw-scryer-laure__scryer_monitor"
            ];
          assert !(gateway.config.mcp.servers ? claw-scryer);
          assert lib.all
            (
              username:
              let
                server = gateway.config.mcp.servers."claw-scryer-${username}";
              in
              server.url == "https://claw-scryer-${username}.hummingbird-lake.ts.net/mcp"
              && server.transport == "streamable-http"
              && !(server ? codex)
              &&
                server.toolFilter.include == [
                  "scryer_graphql"
                  "scryer_search"
                  "scryer_title"
                  "scryer_add"
                  "scryer_monitor"
                ]
            )
            [
              "simon"
              "laure"
            ];
          assert gateway.config.mcp.servers.claw-websearch.transport == "streamable-http";
          assert
            gateway.config.mcp.servers.claw-websearch.url
            == "https://claw-websearch.hummingbird-lake.ts.net/mcp";
          assert gateway.config.mcp.servers.claw-websearch.toolFilter.include == [ "web_search" ];
          assert lib.all (a: !(lib.any (d: lib.hasPrefix "claw-websearch" d) (a.tools.deny or [ ]))) (
            lib.attrValues gateway.config.agents.entries
          );
          assert
            lib.length gateway.config.skills.load.extraDirs == 1
            && lib.pathExists "${lib.head gateway.config.skills.load.extraDirs}/scryer/SKILL.md";
          assert lib.all (
            dir: lib.pathExists "${dir}/research/SKILL.md"
          ) gateway.config.skills.load.extraDirs;
          assert (gateway.config.agents.defaults.subagents.maxChildrenPerAgent or null) == 8;
          assert lib.hasInfix "tell the user the exact error text" (
            builtins.readFile ../lib/openclaw-skills/research/SKILL.md
          );
          assert lib.hasInfix "research inline, one angle at a time" (
            builtins.readFile ../lib/openclaw-skills/research/SKILL.md
          );
          assert !gateway.config.tools.codeMode.enabled && gateway.config.tools.fs.workspaceOnly;
          assert host.systemd.services."container@openclaw".serviceConfig.MemoryMax == "8G";
          # Stop limits. The gateway's limit funds one full ordinary stop. The
          # host's limit outlasts it plus one more guest unit at systemd's 90 s.
          assert unit.KillMode == "mixed" && unit.TimeoutStopSec == 35;
          assert
            host.systemd.services."container@openclaw".serviceConfig.TimeoutStopSec >= unit.TimeoutStopSec + 90;
          assert !gateway.config.tools.elevated.enabled;
          assert gateway.config.browser.enabled && gateway.config.browser.headless;
          assert gateway.config.browser.ssrfPolicy.dangerouslyAllowPrivateNetwork;
          assert gateway.config.agents.defaults.thinkingDefault == "medium";
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
        openclaw-config = pkgs.runCommand "openclaw-config" { } ''
          grep -F "/nix/var/nix/profiles/apps/openclaw/bin/openclaw gateway" ${gateway.execStart}
          export HOME=$TMPDIR
          export OPENCLAW_STATE_DIR=$TMPDIR/state
          export OPENCLAW_CONFIG_PATH=${c.environment.etc."openclaw/openclaw.json".source}
          export FRONT_DOOR_API_KEY=test-only
          export OPENCLAW_GATEWAY_PASSWORD=test-only
          ${gateway.package}/bin/openclaw config validate
          touch $out
        '';
      };
    };
}
