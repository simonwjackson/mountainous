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
  bootstrapDns = pkgs.writeText "claw-overlay-resolv.conf" "nameserver 1.1.1.1\nnameserver 8.8.8.8\n";
  exitNode = "100.120.204.5"; # Unzen's stable tailnet address, not a LAN route.
  admin = pkgs.writeShellApplication {
    name = "openclaw-admin";
    runtimeInputs = [
      pkgs.util-linux
      package
    ];
    text = ''
      FRONT_DOOR_API_KEY="$(cat /run/host-credentials/front-door)"
      OPENCLAW_GATEWAY_TOKEN="$(cat /run/host-credentials/gateway-token)"
      export FRONT_DOOR_API_KEY OPENCLAW_GATEWAY_TOKEN
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
    OPENCLAW_GATEWAY_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/gateway-token")"
    export FRONT_DOOR_API_KEY OPENCLAW_GATEWAY_TOKEN
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
          auth = {
            mode = "token";
            allowTailscale = false;
          };
          trustedProxies = [
            "127.0.0.1"
            "::1"
          ];
          controlUi.allowedOrigins = [ origin ];
        };
        agents.defaults = {
          model.primary = "front-door/claude-opus-5-5";
          workspace = "/var/lib/openclaw/workspace";
        };
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
                  input = [ "text" ];
                })
                [
                  "claude-opus-5-5"
                  "gpt-6.1-sol"
                  "gemini-3.8-flash-high"
                ];
          };
        };
        mcp = {
          servers = {
            basic-react = {
              command = "${demo}/bin/mcp-server-basic-react";
              args = [ "--stdio" ];
            };
          }
          // lib.mapAttrs (name: endpoint: {
            transport = "streamable-http";
            url = "https://${name}.hummingbird-lake.ts.net/mcp";
            toolFilter.include = endpoint.tools;
          }) (import ./claw-tools.nix);
          apps = {
            enabled = true;
            sandboxPort = 18790;
            sandboxOrigin = "${origin}:8443";
          };
        };
        # No channel, marketplace, or bundled skill is admitted in this trial.
        skills.allowBundled = [ ];
        plugins = {
          enabled = false;
          allow = [ ];
        };
        discovery.mdns.mode = "off";
        browser.enabled = false;
        tools = {
          profile = "minimal";
          alsoAllow = [ "bundle-mcp" ];
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
        tailscale serve --bg --https=443 http://127.0.0.1:18789
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
        MemoryMax = "4G";
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
