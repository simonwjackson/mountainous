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
  exitNode = "100.120.204.5"; # Unzen's stable tailnet address, not a LAN route.
  origin = "https://claw.hummingbird-lake.ts.net";
  launch = pkgs.writeShellScript "openclaw-start" ''
    export FRONT_DOOR_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/front-door")"
    export OPENCLAW_GATEWAY_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/gateway-token")"
    exec ${package}/bin/openclaw gateway --port 18789
  '';
in
{
  imports = [ inputs.nix-openclaw.nixosModules.openclaw-gateway ];
  system.stateVersion = "26.05";
  networking = {
    hostName = "claw";
    useHostResolvConf = false;
    nameservers = [ "100.100.100.100" ];
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
          servers.basic-react = {
            command = "${demo}/bin/mcp-server-basic-react";
            args = [ "--stdio" ];
          };
          apps = {
            enabled = true;
            sandboxPort = 18790;
            sandboxOrigin = "${origin}:8443";
          };
        };
        # No channel, marketplace, or bundled skill is admitted in this trial.
        skills.allowBundled = [ ];
        plugins.allow = [ ];
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
            tailscale up --auth-key="$(cat /run/host-credentials/oauth-secret)?ephemeral=false&preauthorized=true" \
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
  environment.systemPackages = [
    package
    pkgs.curl
    pkgs.jq
  ];
}
