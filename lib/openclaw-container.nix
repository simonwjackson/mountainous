{
  inputs,
  profilePath ? "/nix/var/nix/profiles/apps/openclaw",
  person,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  package = import ./openclaw-package.nix { inherit pkgs inputs; };
  identityProxy = import ./claw-identity-proxy.nix { inherit pkgs; };
  # Native catalog limits, approved by Simon and probed through openclaw@yari.
  # contextTokens is an active-input budget, not the model's native window.
  chatModelLimits = {
    "claude-opus-5-5" = {
      contextWindow = 1000000;
      maxTokens = 128000;
    };
    "gpt-6.1-sol" = {
      contextWindow = 500000;
      maxTokens = 128000;
      contextTokens = 272000;
    };
    "gemini-3.8-flash-high" = {
      contextWindow = 1048576;
      maxTokens = 65536;
    };
  };
  # The Scryer MCP App's tools (packages/media-tsnet-proxy/scryer_app.go).
  scryerAppTools = [
    "scryer_search"
    "scryer_title"
    "scryer_add"
    "scryer_monitor"
  ];
  bootstrapDns = pkgs.writeText "claw-overlay-resolv.conf" "nameserver 1.1.1.1\nnameserver 8.8.8.8\n";
  exitNode = "100.88.212.117"; # Rakku's stable tailnet address, not a LAN route.
  admin = pkgs.writeShellApplication {
    name = "openclaw-admin";
    runtimeInputs = [
      pkgs.util-linux
    ];
    text = ''
      FRONT_DOOR_API_KEY="$(cat /run/host-credentials/front-door)"
      # The local admin password; browsers sign in through Tailscale instead.
      OPENCLAW_GATEWAY_PASSWORD="$(cat /run/host-credentials/gateway-token)"
      export FRONT_DOOR_API_KEY OPENCLAW_GATEWAY_PASSWORD
      export OPENCLAW_STATE_DIR=/var/lib/openclaw
      export OPENCLAW_CONFIG_PATH=/etc/openclaw/openclaw.json
      cd /var/lib/openclaw
      exec runuser -u openclaw -- ${profilePath}/bin/openclaw "$@"
    '';
  };
  morningBrief = pkgs.writeText "openclaw-morning-brief.json" (
    builtins.toJSON (
      (import ./openclaw-morning-brief.nix)
      // {
        agentId = person.agentId;
        sessionKey = "agent:${person.agentId}:main";
        description = "Daily supported day plan for ${person.name}";
        payload = (import ./openclaw-morning-brief.nix).payload // {
          message = person.morningBriefPrompt;
        };
      }
    )
  );
  ensureMorningBrief = pkgs.writeShellApplication {
    name = "openclaw-ensure-morning-brief";
    runtimeInputs = [
      admin
      pkgs.jq
    ];
    text = ''
      call_gateway() {
        local result
        if ! result=$(openclaw-admin gateway call "$1" --json --timeout 30000 --params "$2"); then
          printf '%s\n' "$result" >&2
          return 1
        fi
        printf '%s\n' "$result"
      }
      # declarationKey atomically retains the job ID and history across retries.
      result=$(call_gateway cron.add "$(cat ${morningBrief})")
      id=$(jq -er '(.job // .).id' <<< "$result")
      # 2026.11.3 declarations only converge schedule/payload/delivery/enablement.
      # Patch the other authored fields too, rather than preserving UI drift.
      patch=$(jq -n --arg id "$id" --slurpfile job ${morningBrief} \
        '{id: $id, patch: ($job[0] | del(.declarationKey))}')
      result=$(call_gateway cron.update "$patch")
      jq -e --arg id "$id" '(.job // .).id == $id' <<< "$result" >/dev/null
    '';
  };
  windDown = pkgs.writeText "openclaw-wind-down.json" (
    builtins.toJSON (import ./openclaw-wind-down.nix)
  );
  ensureWindDown = pkgs.writeShellApplication {
    name = "openclaw-ensure-wind-down";
    runtimeInputs = [
      admin
      pkgs.jq
    ];
    text = ''
      call_gateway() {
        local result
        if ! result=$(openclaw-admin gateway call "$1" --json --timeout 30000 --params "$2"); then
          printf '%s\n' "$result" >&2
          return 1
        fi
        printf '%s\n' "$result"
      }
      # declarationKey atomically retains the job ID and history across retries.
      result=$(call_gateway cron.add "$(cat ${windDown})")
      id=$(jq -er '(.job // .).id' <<< "$result")
      # 2026.11.3 declarations only converge schedule/payload/delivery/enablement.
      # Patch the other authored fields too, rather than preserving UI drift.
      patch=$(jq -n --arg id "$id" --slurpfile job ${windDown} \
        '{id: $id, patch: ($job[0] | del(.declarationKey))}')
      result=$(call_gateway cron.update "$patch")
      jq -e --arg id "$id" '(.job // .).id == $id' <<< "$result" >/dev/null
    '';
  };
  ebaySelling = pkgs.writeText "openclaw-ebay-selling.json" (
    builtins.toJSON (import ./openclaw-ebay-selling.nix)
  );
  ensureEbaySelling = pkgs.writeShellApplication {
    name = "openclaw-ensure-ebay-selling";
    runtimeInputs = [
      admin
      pkgs.jq
    ];
    text = ''
      call_gateway() {
        local result
        if ! result=$(openclaw-admin gateway call "$1" --json --timeout 30000 --params "$2"); then
          printf '%s\n' "$result" >&2
          return 1
        fi
        printf '%s\n' "$result"
      }
      # declarationKey atomically retains the job ID and history across retries.
      result=$(call_gateway cron.add "$(cat ${ebaySelling})")
      id=$(jq -er '(.job // .).id' <<< "$result")
      # 2026.11.3 declarations only converge schedule/payload/delivery/enablement.
      # Patch the other authored fields too, rather than preserving UI drift.
      patch=$(jq -n --arg id "$id" --slurpfile job ${ebaySelling} \
        '{id: $id, patch: ($job[0] | del(.declarationKey))}')
      result=$(call_gateway cron.update "$patch")
      jq -e --arg id "$id" '(.job // .).id == $id' <<< "$result" >/dev/null
    '';
  };
  mailFiling = pkgs.writeText "openclaw-mail-filing.json" (builtins.toJSON person.mailFilingJob);
  ensureMailFiling = pkgs.writeShellApplication {
    name = "openclaw-ensure-mail-filing";
    runtimeInputs = [
      admin
      pkgs.jq
    ];
    text = ''
      call_gateway() {
        local result
        if ! result=$(openclaw-admin gateway call "$1" --json --timeout 30000 --params "$2"); then
          printf '%s\n' "$result" >&2
          return 1
        fi
        printf '%s\n' "$result"
      }
      # declarationKey atomically retains the job ID and history across retries.
      result=$(call_gateway cron.add "$(cat ${mailFiling})")
      id=$(jq -er '(.job // .).id' <<< "$result")
      # 2026.11.3 declarations only converge schedule/payload/delivery/enablement.
      # Patch the other authored fields too, rather than preserving UI drift.
      patch=$(jq -n --arg id "$id" --slurpfile job ${mailFiling} \
        '{id: $id, patch: ($job[0] | del(.declarationKey))}')
      result=$(call_gateway cron.update "$patch")
      jq -e --arg id "$id" '(.job // .).id == $id' <<< "$result" >/dev/null
    '';
  };
  origin = "https://${person.nodeName}.hummingbird-lake.ts.net";
  launch = pkgs.writeShellScript "openclaw-start" ''
    set -euo pipefail
    FRONT_DOOR_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/front-door")"
    OPENCLAW_GATEWAY_PASSWORD="$(cat "$CREDENTIALS_DIRECTORY/gateway-token")"
    export FRONT_DOOR_API_KEY OPENCLAW_GATEWAY_PASSWORD
    exec ${profilePath}/bin/openclaw gateway --port 18789
  '';
in
{
  imports = [ inputs.nix-openclaw.nixosModules.openclaw-gateway ];
  system.stateVersion = "26.05";
  networking = {
    hostName = person.nodeName;
    useHostResolvConf = false;
    nameservers = [ "127.0.0.1" ];
    firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" ];
    };
    nftables = {
      enable = true;
      # No established-connection shortcut: an existing socket cannot survive
      # exit-node loss by switching to eth0. IPv4 AND IPv6 fail closed. Only
      # the trusted overlay daemon may bootstrap outside the overlay.
      tables.openclaw-egress = {
        family = "inet";
        content = ''
          chain output {
            type filter hook output priority 0; policy drop;
            oifname "lo" accept
            oifname "tailscale0" accept
            meta skuid ${toString config.users.users.tailscale.uid} accept
          }
        '';
      };
    };
  };
  services = {
    resolved.enable = false;
    # Quad100 resolves tailnet names but has no public forwarder when DNS
    # management is disabled. This split resolver's public queries are still
    # confined to tailscale0 by the same OUTPUT policy as the app.
    dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        listen-address = "127.0.0.1";
        bind-interfaces = true;
        no-resolv = true;
        server = [
          "/hummingbird-lake.ts.net/100.100.100.100"
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
    };
    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
      openFirewall = true;
      extraSetFlags = [ ];
    };
    openclaw-gateway = {
      enable = true;
      inherit package;
      execStart = "${launch}";
      restartSec = 10;
      environment = {
        HOME = "/var/lib/openclaw";
        OPENCLAW_NIX_MODE = "1";
        OPENCLAW_DISABLE_PERSISTED_PLUGIN_REGISTRY = "1";
      };
      config = {
        gateway = {
          mode = "local";
          bind = "loopback";
          port = 18789;
          publicOrigin = origin;
          # Per-person sign-in. claw-tailnet's own `tailscale serve` deletes any
          # client Tailscale-User-* headers and sets the WhoIs login (none for
          # tagged nodes). OpenClaw gets no tailscaled access (InaccessiblePaths).
          # Loopback trust means a process in this container could forge a
          # login; the gateway user is already the untrusted party, and its
          # agents have no shell tool. The password (OPENCLAW_GATEWAY_PASSWORD)
          # works only for local-direct clients: openclaw-admin and the brief.
          auth = {
            mode = "trusted-proxy";
            allowTailscale = false;
            trustedProxy = {
              userHeader = "tailscale-user-login";
              requiredHeaders = [
                "x-forwarded-proto"
                "x-forwarded-host"
              ];
              allowUsers = [ person.login ];
              allowLoopback = true;
            };
          };
          # One non-admin person; same-agent sub-agents need sessions.others=write.
          roles = {
            default = person.roleName;
            definitions.${person.roleName} = {
              sessions.others = "write";
              agents = [ person.agentId ];
              scopes = [
                "operator.read"
                "operator.write"
                "operator.approvals"
                "operator.questions"
              ];
            };
          };
          trustedProxies = [
            "127.0.0.1"
            "::1"
          ];
          controlUi.allowedOrigins = [ origin ];
        };
        agents = {
          # Two agents need explicit owners. These pin, for main, what the
          # retired `default = true` marker meant (as `openclaw doctor --fix`).
          ownership = "explicit";
          defaults = {
            thinkingDefault = "medium";
            subagents.maxChildrenPerAgent = 8;
            mediaModels.image = {
              primary = "openai/gemini-3.1-flash-image";
              fallbacks = [ "openai/gpt-image-2" ];
            };
            model.primary = "front-door/claude-opus-5-5";
            workspace = person.workspacePath;
            systemAgent.agentId = person.agentId;
            sessionStore.agentId = person.agentId;
          };
          entries = {
            ${person.agentId} = {
              identity = person.identity;
              workspace = person.workspacePath;
              agentDir = "/var/lib/openclaw/agents/${person.agentId}/agent";
              heartbeat.every = "30m";
            }
            // lib.optionalAttrs (person ? agentTools) { tools = person.agentTools; };
          }
          // (person.extraAgents or { });
        };
        talk.agentId = person.agentId;
        models = {
          mode = "replace";
          providers.front-door = {
            baseUrl = "https://ai.hummingbird-lake.ts.net/v1";
            timeoutSeconds = 600;
            apiKey = "\${FRONT_DOOR_API_KEY}";
            api = "openai-completions";
            models =
              map
                (
                  id:
                  {
                    inherit id;
                    name = id;
                    input = [
                      "text"
                      "image"
                    ];
                    reasoning = true;
                  }
                  // chatModelLimits.${id}
                )
                [
                  "claude-opus-5-5"
                  "gpt-6.1-sol"
                  "gemini-3.8-flash-high"
                ];
          };
        };
        # Use the Images dialect, not Gemini's native API, at the same front door.
        models.providers.openai = {
          baseUrl = "https://ai.hummingbird-lake.ts.net/v1";
          timeoutSeconds = 600;
          apiKey = "\${FRONT_DOOR_API_KEY}";
          api = "openai-completions";
          models =
            map
              (id: {
                inherit id;
                name = id;
              })
              [
                "gemini-3.1-flash-image"
                "gpt-image-2"
              ];
        };
        # The front-door grant has no embeddings dialect. Keep memory local/FTS.
        memory.search.provider = "none";
        mcp = {
          sessionIdleTtlMs = 600000;
          servers =
            lib.mapAttrs (
              name: endpoint:
              {
                transport = "streamable-http";
                # A server with a row is on the production front door
                # (lib/ai-mcp-rows.nix); the others have their own node.
                url =
                  if endpoint ? row then
                    "https://ai.hummingbird-lake.ts.net/mcp/${endpoint.row}"
                  else
                    "https://${name}.hummingbird-lake.ts.net/mcp";
                toolFilter.include = endpoint.tools;
              }
              // lib.optionalAttrs (endpoint ? codex) { inherit (endpoint) codex; }
            ) ((lib.filterAttrs (name: _: name == "claw-maps") (import ./claw-tools.nix)) // person.mcpServers)
            // {
              claw-websearch = {
                transport = "streamable-http";
                url = "https://claw-websearch.hummingbird-lake.ts.net/mcp";
                toolFilter.include = [ "web_search" ];
              };
            }
            // lib.listToAttrs (
              map (
                server:
                if server ? bundledDemoTool then
                  let
                    demo = import ./openclaw-demo.nix {
                      inherit pkgs inputs;
                      node = package.runtimeNode;
                      name = server.name;
                      tool = server.bundledDemoTool;
                    };
                  in
                  {
                    inherit (server) name;
                    value = {
                      command = "${demo}/bin/mcp-server-${server.name}";
                      args = [ "--stdio" ];
                    };
                  }
                else
                  server
              ) (person.extraMcpServers or [ ])
            );
          apps = {
            enabled = true;
            sandboxPort = 18790;
            sandboxOrigin = "${origin}:8443";
          };
        };
        skills.allowBundled = [
          "weather"
          "visualize"
          "diagram-maker"
        ];
        skills.entries.clawhub.enabled = false;
        # Shared by both agents: the hand-kept skills in lib/openclaw-skills.
        skills.load.extraDirs = [
          "${./openclaw-skills/shared}"
          "${./openclaw-skills + "/${person.name}"}"
        ]
        ++ (person.extraSkillFolders or [ ]);
        # Only the plugins needed by the approved browser, memory, images and web tools.
        plugins = {
          enabled = true;
          allow = [
            "browser"
            "memory-core"
            "openai"
            "web-readability"
            "session-share"
          ]
          ++ (person.extraPlugins or [ ]);
          entries.session-share = {
            enabled = true;
            config.share.groups = [ "Shared" ];
          };
        };
        discovery.mdns.mode = "off";
        browser = {
          enabled = true;
          headless = true;
          defaultProfile = "openclaw";
          executablePath = "${pkgs.chromium}/bin/chromium";
          # 2026.11.3's Images adapter only honors this shared opt-in, not
          # allowedHostnames or providers.openai.request.allowPrivateNetwork.
          # Tailnet ACLs and the fail-closed container firewall remain the boundary.
          ssrfPolicy.dangerouslyAllowPrivateNetwork = true;
        };
        tools = {
          profile = "full";
          allow = [
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
          ]
          ++ lib.concatMap (name: map (tool: "${name}__${tool}") scryerAppTools) (
            lib.filter (name: lib.hasPrefix "claw-scryer-" name) (lib.attrNames person.mcpServers)
          )
          ++ (person.extraToolPermissions or [ ]);
          deny = [
            "group:runtime"
            "web_search"
          ];
          sessions.visibility = "agent";
          agentToAgent = person.agentToAgent or { enabled = false; };
          codeMode.enabled = false;
          fs.workspaceOnly = true;
          elevated.enabled = false;
        };
        update.checkOnStart = false;
        logging.file = "/var/lib/openclaw/logs/openclaw.log";
      };
    };
  };
  users = {
    groups.tailscale = { };
    users = {
      tailscale = {
        isSystemUser = true;
        uid = 991;
        group = "tailscale";
      };
      openclaw = {
        uid = 992;
        shell = lib.mkForce "${pkgs.shadow}/bin/nologin";
      };
    };
  };
  systemd.services = {
    # Bootstrap reads reject symlinks outside the workspace. Install real files,
    # not store symlinks. The reader has no file tools to change these documents.
    openclaw-agent-instructions = lib.mkIf (person ? extraAgentInstructions) {
      description = "Install declarative restricted-agent instructions";
      requiredBy = [ "openclaw-gateway.service" ];
      before = [ "openclaw-gateway.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          id: directory:
          let
            workspace = person.extraAgents.${id}.workspace;
          in
          ''
            ${pkgs.coreutils}/bin/install -d -m 0700 -o openclaw -g openclaw ${workspace}
          ''
          +
            lib.concatMapStringsSep "\n"
              (file: ''
                ${pkgs.coreutils}/bin/install -m 0444 ${directory}/${file} ${workspace}/${file}
              '')
              [
                "AGENTS.md"
                "SOUL.md"
                "BOOTSTRAP.md"
              ]
        ) person.extraAgentInstructions
      );
    };
    # Tailscale Serve sets no login for tagged devices. Simon's own fleet
    # machines (Myoko, Ibuki, ...) carry tag:mountainous, so this proxy names
    # Simon for that tag only. It asks tailscaled read-only (WhoIs); it has no
    # operator rights. Logins Serve sets pass through unchanged.
    claw-identity-proxy = lib.mkIf (person.name == "simon") {
      description = "Name the person for tagged devices at Claw's Tailscale Serve";
      wantedBy = [ "multi-user.target" ];
      after = [ "tailscaled.service" ];
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          "${identityProxy}/bin/claw-identity-proxy"
          "-listen 127.0.0.1:18788"
          "-upstream http://127.0.0.1:18789"
          "-tailscale ${config.services.tailscale.package}/bin/tailscale"
          "-tag tag:mountainous"
          "-login simon.jackson@gmail.com"
        ];
        DynamicUser = true;
        Restart = "always";
        RestartSec = 5;
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        MemoryMax = "256M";
      };
    };
    openclaw-morning-brief = lib.mkIf (person.enableMorningBrief or false) {
      description = "Reconcile the declarative 07:00 Denver OpenClaw morning brief";
      wantedBy = [ "multi-user.target" ];
      requires = [ "openclaw-gateway.service" ];
      after = [ "openclaw-gateway.service" ];
      partOf = [ "openclaw-gateway.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe ensureMorningBrief;
        Restart = "on-failure";
        RestartSec = 15;
      };
      unitConfig.StartLimitIntervalSec = 0;
    };
    openclaw-wind-down = lib.mkIf (person.enableWindDown or false) {
      description = "Reconcile the declarative 21:00 Denver OpenClaw wind-down opener";
      wantedBy = [ "multi-user.target" ];
      requires = [ "openclaw-gateway.service" ];
      after = [ "openclaw-gateway.service" ];
      partOf = [ "openclaw-gateway.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe ensureWindDown;
        Restart = "on-failure";
        RestartSec = 15;
      };
      unitConfig.StartLimitIntervalSec = 0;
    };
    openclaw-ebay-selling = lib.mkIf (person.enableEbaySelling or false) {
      description = "Reconcile the declarative 08:00 Denver eBay selling drafts";
      wantedBy = [ "multi-user.target" ];
      requires = [ "openclaw-gateway.service" ];
      after = [ "openclaw-gateway.service" ];
      partOf = [ "openclaw-gateway.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe ensureEbaySelling;
        Restart = "on-failure";
        RestartSec = 15;
      };
      unitConfig.StartLimitIntervalSec = 0;
    };
    openclaw-mail-filing = lib.mkIf (person ? mailFilingJob) {
      description = "Reconcile the declarative hourly Not Me mail filing";
      wantedBy = [ "multi-user.target" ];
      requires = [ "openclaw-gateway.service" ];
      after = [ "openclaw-gateway.service" ];
      partOf = [ "openclaw-gateway.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe ensureMailFiling;
        Restart = "on-failure";
        RestartSec = 15;
      };
      unitConfig.StartLimitIntervalSec = 0;
    };
    openclaw-session-share = {
      description = "Read-only Session Share source connected to the other person's gateway";
      wantedBy = [ "multi-user.target" ];
      after = [
        "openclaw-gateway.service"
        "claw-tailnet.service"
      ];
      environment = {
        HOME = "/var/lib/openclaw";
        OPENCLAW_STATE_DIR = "/var/lib/openclaw";
        OPENCLAW_CONFIG_PATH = "/etc/openclaw/openclaw.json";
        OPENCLAW_NIX_MODE = "1";
      };
      script = ''
        FRONT_DOOR_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/front-door")"
        export FRONT_DOOR_API_KEY
        exec ${profilePath}/bin/openclaw node run --host ${person.peerNodeName}.hummingbird-lake.ts.net --port 443 --tls --commands openclaw.sessions.list.v1,openclaw.sessions.read.v1
      '';
      serviceConfig = {
        User = "openclaw";
        Group = "openclaw";
        LoadCredential = [ "front-door:/run/host-credentials/front-door" ];
        Restart = "always";
        RestartSec = 10;
        UMask = "0077";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/openclaw" ];
        InaccessiblePaths = [
          "/nix/var/nix/daemon-socket"
          "/run/host-credentials"
          "/run/tailscale"
        ];
        MemoryMax = "1G";
      };
    };
    tailscaled.serviceConfig = {
      User = "tailscale";
      Group = "tailscale";
      StateDirectory = "tailscale";
      RuntimeDirectory = "tailscale";
      AmbientCapabilities = [
        "CAP_NET_ADMIN"
        "CAP_NET_RAW"
      ];
      CapabilityBoundingSet = [
        "CAP_NET_ADMIN"
        "CAP_NET_RAW"
      ];
      NoNewPrivileges = true;
      BindReadOnlyPaths = [ "${bootstrapDns}:/etc/resolv.conf" ];
    };
    # --hostname applies only when the node first joins. A registered node keeps
    # its name and ID across restarts; renaming one is a one-time, in-place
    # `tailscale set --hostname=NEW` while it runs, then Serve again under the
    # new DNS name (docs/operations/openclaw-yari.md, "Rename to flakey").
    claw-tailnet = {
      description = "Join the isolated Claw node and select only the home exit node";
      wantedBy = [ "multi-user.target" ];
      requires = [
        "tailscaled.service"
        "nftables.service"
      ];
      wants = [ "network-online.target" ];
      after = [
        "tailscaled.service"
        "nftables.service"
        "network-online.target"
      ];
      path = [
        pkgs.tailscale
        pkgs.jq
      ];
      script = ''
        set -euo pipefail
        status=$(tailscale status --json)
        state=$(printf '%s' "$status" | jq -r .BackendState)
        case "$state" in
          NeedsLogin|NoState)
            tailscale up --auth-key="$(cat "$CREDENTIALS_DIRECTORY/oauth-secret")?ephemeral=false&preauthorized=true" \
              --hostname=${person.nodeName} --advertise-tags=tag:claw --ssh=false \
              --accept-dns=false --accept-routes=false --exit-node=${exitNode} \
              --exit-node-allow-lan-access=false
            ;;
          Running|Starting) ;;
          *) echo "Unexpected Tailscale state $state; preserving identity" >&2; exit 1 ;;
        esac
        tailscale set --ssh=false --accept-dns=false --accept-routes=false \
          --exit-node=${exitNode} --exit-node-allow-lan-access=false
        # Through claw-identity-proxy, which names the person for tagged devices.
        tailscale serve --bg --https=443 http://127.0.0.1:${
          if person.name == "simon" then "18788" else "18789"
        }
        tailscale serve --bg --https=8443 http://127.0.0.1:18790
      '';
      serviceConfig = {
        User = "tailscale";
        Group = "tailscale";
        LoadCredential = [ "oauth-secret:/run/host-credentials/oauth-secret" ];
        BindReadOnlyPaths = [ "${bootstrapDns}:/etc/resolv.conf" ];
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 15;
      };
      unitConfig.StartLimitIntervalSec = 0;
    };
    openclaw-gateway = {
      after = [
        "claw-tailnet.service"
        "nftables.service"
      ];
      requires = [ "nftables.service" ];
      wants = [ "claw-tailnet.service" ];
      serviceConfig = {
        LoadCredential = [
          "front-door:/run/host-credentials/front-door"
          "gateway-token:/run/host-credentials/gateway-token"
        ];
        # Nspawn shares the host's Nix daemon socket by default. Read-only
        # mounting a Unix socket does not stop clients connecting to it.
        InaccessiblePaths = [
          "/nix/var/nix/daemon-socket"
          "/run/host-credentials"
          "/run/tailscale"
        ];
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectProc = "invisible";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        RestrictRealtime = true;
        CapabilityBoundingSet = "";
        UMask = "0077";
        StateDirectory = "openclaw";
        StateDirectoryMode = "0700";
        ReadWritePaths = [ "/var/lib/openclaw" ];
        MemoryMax = "8G";
        TasksMax = 2048;
        # OpenClaw requires mixed (its docs/gateway/restart-recovery.md): only
        # the gateway gets the stop signal, so its children live while it closes.
        KillMode = "mixed";
        # The gateway reads this limit and gives up 5 s before it. 35 s funds
        # one full ordinary stop: 20 s drain, 10 s cleanup, 5 s margin. At the
        # 90 s default, a close step that never returns held each stop 87 s.
        TimeoutStopSec = 35;
      };
    };
  };
  # The service's strict mount namespace keeps this declarative file read-only.
  # A private /etc copy also satisfies OpenClaw's config-permission audit.
  environment.etc."openclaw/openclaw.json" = {
    mode = lib.mkForce "0600";
    user = "openclaw";
    group = "openclaw";
  };
  environment.systemPackages = [
    admin
    package
    pkgs.curl
    pkgs.jq
  ];
}
