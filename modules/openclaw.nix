{ inputs, self, ... }:
{
  nixos.modules.openclaw =
    { config, lib, ... }:
    {
      options.mountainous.features.openclaw.enable = lib.mkEnableOption "isolated OpenClaw trial" // {
        default = true;
      };
      config = lib.mkIf config.mountainous.features.openclaw.enable {
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
          config = import ../lib/openclaw-container.nix { inherit inputs; };
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
          assert container.privateNetwork && container.enableTun && container.autoStart;
          assert gateway.config.gateway.bind == "loopback";
          assert gateway.config.gateway.auth.mode == "token" && !gateway.config.gateway.auth.allowTailscale;
          assert
            gateway.config.models.providers.front-door.baseUrl == "https://ai.hummingbird-lake.ts.net/v1";
          assert gateway.config.agents.defaults.model.primary == "front-door/claude-opus-5-5";
          assert gateway.config.mcp.apps.enabled;
          assert gateway.config.mcp.apps.sandboxOrigin == "https://claw.hummingbird-lake.ts.net:8443";
          assert lib.hasInfix "--exit-node=100.120.204.5" c.systemd.services.claw-tailnet.script;
          assert lib.hasInfix "--exit-node-allow-lan-access=false" c.systemd.services.claw-tailnet.script;
          assert
            lib.hasInfix "policy drop;" firewall && lib.hasInfix "oifname \"tailscale0\" accept" firewall;
          assert lib.hasInfix "meta skuid 991 accept" firewall;
          assert c.users.users.openclaw.uid != c.users.users.tailscale.uid;
          assert c.systemd.services.tailscaled.serviceConfig.User == "tailscale";
          assert
            unit.ProtectSystem == "strict" && unit.ProtectHome && unit.NoNewPrivileges && unit.PrivateTmp;
          assert unit.ReadWritePaths == [ "/var/lib/openclaw" ] && unit.MemoryMax == "4G";
          assert gateway.config.skills.allowBundled == [ ] && gateway.config.plugins.allow == [ ];
          assert !(gateway.config ? channels);
          assert host.networking.firewall.allowedTCPPorts == [ ];
          assert
            key.models == [
              "claude-opus-5-5"
              "gpt-6.1-sol"
              "gemini-3.8-flash-high"
            ];
          assert
            key.dialects == [
              "chat_completions"
              "responses"
              "models"
            ];
          assert key.monthly_cap_usd == 1 && key.requests_per_minute == 300;
          pkgs.runCommand "openclaw-isolation" { } "touch $out";
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isAarch64 {
        openclaw-config = pkgs.runCommand "openclaw-config" { } ''
          export HOME=$TMPDIR
          export OPENCLAW_STATE_DIR=$TMPDIR/state
          export OPENCLAW_CONFIG_PATH=${c.environment.etc."openclaw/openclaw.json".source}
          export FRONT_DOOR_API_KEY=test-only
          export OPENCLAW_GATEWAY_TOKEN=test-only
          ${gateway.package}/bin/openclaw config validate
          touch $out
        '';
      };
    };
}
