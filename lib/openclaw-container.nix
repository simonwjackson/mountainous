{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  package = import ./openclaw-package.nix { inherit pkgs inputs; };
  demo = import ./openclaw-demo.nix {
    inherit pkgs inputs;
    node = package.runtimeNode;
  };
  interactiveDemos =
    lib.mapAttrs
      (
        name: tool:
        import ./openclaw-demo.nix {
          inherit
            pkgs
            inputs
            name
            tool
            ;
          node = package.runtimeNode;
        }
      )
      {
        budget-allocator = "get-budget-data";
      };
  identityProxy = import ./claw-identity-proxy.nix { inherit pkgs; };
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
      package
    ];
    text = ''
      FRONT_DOOR_API_KEY="$(cat /run/host-credentials/front-door)"
      # The local admin password; browsers sign in through Tailscale instead.
      OPENCLAW_GATEWAY_PASSWORD="$(cat /run/host-credentials/gateway-token)"
      export FRONT_DOOR_API_KEY OPENCLAW_GATEWAY_PASSWORD
      export OPENCLAW_STATE_DIR=/var/lib/openclaw
      export OPENCLAW_CONFIG_PATH=/etc/openclaw/openclaw.json
      cd /var/lib/openclaw
      exec runuser -u openclaw -- openclaw "$@"
    '';
  };
  morningBrief = pkgs.writeText "openclaw-morning-brief.json" (
    builtins.toJSON (import ./openclaw-morning-brief.nix)
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
  origin = "https://claw.hummingbird-lake.ts.net";
  launch = pkgs.writeShellScript "openclaw-start" ''
    set -euo pipefail
    FRONT_DOOR_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/front-door")"
    OPENCLAW_GATEWAY_PASSWORD="$(cat "$CREDENTIALS_DIRECTORY/gateway-token")"
    export FRONT_DOOR_API_KEY OPENCLAW_GATEWAY_PASSWORD
    exec ${package}/bin/openclaw gateway --port 18789
  '';
in
{
  imports = [ inputs.nix-openclaw.nixosModules.openclaw-gateway ];
  system.stateVersion = "26.05";
  networking = {
    hostName = "claw";
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
              allowUsers = [
                "simon.jackson@gmail.com"
                "chancerellelaure@gmail.com"
              ];
              allowLoopback = true;
            };
          };
          # Non-admin roles, each limited to the person's own agent. Assign with
          # users.setRole from the CLI after the first sign-in; until then a
          # profile gets "pending": no agents and no scopes.
          roles = {
            default = "pending";
            definitions =
              let
                person = agent: {
                  sessions.others = "view";
                  agents = [ agent ];
                  scopes = [
                    "operator.read"
                    "operator.write"
                    "operator.approvals"
                    "operator.questions"
                  ];
                };
              in
              {
                pending = {
                  sessions.others = "none";
                  agents = [ ];
                  scopes = [ ];
                };
                simon = person "main";
                laure = person "laure";
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
            mediaModels.image = {
              primary = "openai/gemini-3.1-flash-image";
              fallbacks = [ "openai/gpt-image-2" ];
            };
            model.primary = "front-door/claude-opus-5-5";
            workspace = "/var/lib/openclaw/workspace";
            systemAgent.agentId = "main";
            sessionStore.agentId = "main";
          };
          # Two agents: when any entry has a heartbeat block, only those agents
          # run heartbeats, and a multi-agent roster without blocks runs none.
          # Both keep the 30-minute default explicitly.
          entries = {
            # Simon's agent (persona flakey), unchanged except it does not get
            # Laure's Family calendar tool.
            main = {
              workspace = "/var/lib/openclaw/workspace";
              heartbeat.every = "30m";
              tools.deny = [ "claw-family-calendar__*" ];
            };
            # Laure's agent. Its persona comes from her own BOOTSTRAP.md
            # interview; OpenClaw seeds the starter files on the first run.
            laure = {
              workspace = "/var/lib/openclaw/workspace-laure";
              agentDir = "/var/lib/openclaw/agents/laure/agent";
              heartbeat.every = "30m";
              tools.deny = [
                "claw-calendar__*"
                "basic-react__*"
                "budget-allocator__*"
                "system-monitor__*"
              ];
            };
          };
        };
        talk.agentId = "main";
        models = {
          mode = "replace";
          providers.front-door = {
            baseUrl = "https://ai.hummingbird-lake.ts.net/v1";
            apiKey = "\${FRONT_DOOR_API_KEY}";
            api = "openai-completions";
            models =
              map
                (id: {
                  inherit id;
                  name = id;
                  input = [
                    "text"
                    "image"
                  ];
                  reasoning = true;
                })
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
          servers = {
            basic-react = {
              command = "${demo}/bin/mcp-server-basic-react";
              args = [ "--stdio" ];
            };
          }
          // lib.mapAttrs (name: demoPackage: {
            command = "${demoPackage}/bin/mcp-server-${name}";
            args = [ "--stdio" ];
          }) interactiveDemos
          // lib.mapAttrs (name: endpoint: {
            transport = "streamable-http";
            url = "https://${name}.hummingbird-lake.ts.net/mcp";
            toolFilter.include = endpoint.tools;
          }) (import ./claw-tools.nix)
          // {
            # Full-admin Scryer (see docs/operations/openclaw-yari.md) and its MCP App.
            # The four app tools are also allowed by exact name in tools.allow below,
            # because OpenClaw checks a card's own tool calls by projected name.
            claw-scryer = {
              transport = "streamable-http";
              url = "https://claw-scryer.hummingbird-lake.ts.net/mcp";
              toolFilter.include = [
                "scryer_graphql"
              ]
              ++ scryerAppTools;
            };
          };
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
        # Shared by both agents: the prepared Scryer skill (lib/openclaw-skills/scryer).
        skills.load.extraDirs = [ "${./openclaw-skills}" ];
        # Only the plugins needed by the approved browser, memory, images and web tools.
        plugins = {
          enabled = true;
          allow = [
            "browser"
            "memory-core"
            "openai"
            "web-readability"
          ];
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
          # Exact names, so the Scryer card's buttons pass the session tool policy.
          # Nothing else from claw-scryer is added; scryer_graphql stays model-only in effect.
          ++ map (tool: "claw-scryer__${tool}") scryerAppTools;
          deny = [ "group:runtime" ];
          sessions.visibility = "agent";
          agentToAgent.enabled = false;
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
    # Tailscale Serve sets no login for tagged devices. Simon's own fleet
    # machines (Myoko, Ibuki, ...) carry tag:mountainous, so this proxy names
    # Simon for that tag only. It asks tailscaled read-only (WhoIs); it has no
    # operator rights. Logins Serve sets pass through unchanged.
    claw-identity-proxy = {
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
    openclaw-morning-brief = {
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
              --hostname=claw --advertise-tags=tag:claw --ssh=false \
              --accept-dns=false --accept-routes=false --exit-node=${exitNode} \
              --exit-node-allow-lan-access=false
            ;;
          Running|Starting) ;;
          *) echo "Unexpected Tailscale state $state; preserving identity" >&2; exit 1 ;;
        esac
        tailscale set --ssh=false --accept-dns=false --accept-routes=false \
          --exit-node=${exitNode} --exit-node-allow-lan-access=false
        # Through claw-identity-proxy, which names the person for tagged devices.
        tailscale serve --bg --https=443 http://127.0.0.1:18788
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
        TasksMax = 256;
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
