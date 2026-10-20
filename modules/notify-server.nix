# ntfy is the store; the hub handles write-only buttons and stateless MCP.
{ inputs, self, ... }:
{
  perSystem = { pkgs, lib, ... }: {
    checks.notify-server =
      let
        c = self.nixosConfigurations.rakku.config;
        n = c.services.ntfy-sh;
        persisted = map (
          d: if builtins.isString d then d else d.directory
        ) c.environment.persistence."/tundra/permafrost".directories;
      in
      assert c.mountainous.features.notify-server.enable;
      assert n.package.version == "2.28.0";
      assert n.settings.listen-http == "127.0.0.1:2586";
      assert n.settings.auth-default-access == "deny-all";
      assert n.settings.cache-duration == "720h";
      assert n.environmentFile == c.sops.secrets.notify-server-env.path;
      assert lib.elem "/var/lib/ntfy-sh" persisted;
      assert c.mountainous.tailnetNames ? ntfy;
      assert !(lib.elem 2586 c.networking.firewall.allowedTCPPorts);
      pkgs.runCommand "notify-server-contract" { } "touch $out";
  };

  nixos.modules.notify-server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.notify-server;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.notify-sync;
      current = import inputs.nixpkgs { system = pkgs.stdenv.hostPlatform.system; };
      secrets = config.sops.secrets;
    in
    {
      options.mountainous.features.notify-server.enable = lib.mkEnableOption "tailnet notification hub";
      config = lib.mkIf cfg.enable {
        services.ntfy-sh = {
          enable = true;
          package = current.ntfy-sh;
          environmentFile = secrets.notify-server-env.path;
          settings = {
            base-url = "https://ntfy.hummingbird-lake.ts.net";
            listen-http = "127.0.0.1:2586";
            behind-proxy = true;
            cache-file = "/var/lib/ntfy-sh/cache.db";
            auth-file = "/var/lib/ntfy-sh/auth.db";
            cache-duration = "720h";
            # Publish acknowledgements must mean the revision is in the cache.
            cache-batch-size = 0;
            cache-batch-timeout = "0s";
            auth-default-access = "deny-all";
            visitor-request-limit-exempt-hosts = "100.64.0.0/10,127.0.0.0/8,::1";
          };
        };
        users.groups.ntfy-sh = { };
        users.users.ntfy-sh = {
          isSystemUser = true;
          group = "ntfy-sh";
        };
        # Stable ownership is needed by the persisted directory on both pins.
        systemd.services.ntfy-sh.unitConfig.RequiresMountsFor = [ "/var/lib/ntfy-sh" ];
        systemd.services.ntfy-sh.serviceConfig = {
          DynamicUser = lib.mkForce false;
          User = "ntfy-sh";
          Group = "ntfy-sh";
        };
        environment.persistence."/tundra/permafrost".directories = [
          {
            directory = "/var/lib/ntfy-sh";
            user = "ntfy-sh";
            group = "ntfy-sh";
            mode = "0700";
          }
        ];
        sops.secrets = {
          notify-server-env = {
            sopsFile = ../secrets/notify/server.yaml;
            mode = "0400";
            restartUnits = [ "ntfy-sh.service" ];
          };
          notify-mcp-token = {
            sopsFile = ../secrets/notify/server.yaml;
            mode = "0400";
            restartUnits = [ "notify-hub.service" ];
          };
        };
        systemd.services.notify-hub = {
          description = "Notification Done buttons and stateless MCP";
          wantedBy = [ "multi-user.target" ];
          wants = [
            "network-online.target"
            "ntfy-sh.service"
          ];
          after = [
            "network-online.target"
            "ntfy-sh.service"
          ];
          serviceConfig = {
            ExecStart =
              "${package}/bin/notify-hub --ntfy http://127.0.0.1:2586"
              + " --public-url https://ntfy.hummingbird-lake.ts.net"
              + " --token-file %d/agent --button-token-file %d/button --mcp-token-file %d/mcp";
            LoadCredential = [
              "agent:${secrets.notify-agent-token.path}"
              "button:${secrets.notify-button-token.path}"
              "mcp:${secrets.notify-mcp-token.path}"
            ];
            DynamicUser = true;
            Restart = "on-failure";
            RestartSec = 2;
            NoNewPrivileges = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
            ];
            UMask = "0077";
          };
        };
        # One HTTPS origin. The hub routes /mcp and proxies every ntfy route,
        # including its JSON stream and WebSocket, without buffering.
        mountainous.tailnetNames.ntfy = {
          description = "ntfy notification store and MCP tailnet proxy";
          backend = "http://127.0.0.1:2587";
          after = [ "notify-hub.service" ];
        };
      };
    };
}
