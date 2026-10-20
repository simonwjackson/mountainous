# Host-owned units and storage. Application generations are deployed separately.
{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.cliproxyapi =
        let
          contract = import ../tests/cliproxyapi-contract.nix {
            rakku = self.nixosConfigurations.rakku.config;
            unzen = self.nixosConfigurations.unzen.config;
          };
        in
        assert contract.status == "pass";
        pkgs.runCommand "cliproxyapi-contract" { } "touch $out";
    };

  nixos.modules.cliproxyapi =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.cliproxyapi;
      state = "/var/lib/cliproxyapi";
      profile = "/nix/var/nix/profiles/per-user/cliproxyapi/application";
      ready = "${state}/.migration-ready";
      controller = pkgs.writeShellApplication {
        name = "cliproxyapi-service-control";
        runtimeInputs = [ pkgs.systemd ];
        text = lib.removePrefix "#!/usr/bin/env nix-shell\n#!nix-shell -i bash -p bash systemd\n" (
          builtins.readFile ./cliproxyapi-control.sh
        );
      };
      environment = {
        HOME = state;
        XDG_CONFIG_HOME = "${state}/.config";
        XDG_STATE_HOME = "${state}/.local/state";
        CLIPROXY_AUTH_DIR = "${state}/.cli-proxy-api";
        CLIPROXY_QUOTA_STATE_DIR = "${state}/.local/state/cliproxyapi-quota-router";
      };
      common = {
        User = "cliproxyapi";
        Group = "cliproxyapi";
        WorkingDirectory = state;
        UMask = "0077";
        Restart = "on-failure";
        RestartSec = 3;
        TimeoutStopSec = 30;
        StateDirectory = "cliproxyapi";
        StateDirectoryMode = "0700";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ state ];
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        CapabilityBoundingSet = "";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
      };
      # The core owns config.yaml and rewrites it through its management API,
      # so the Gemini key is pushed through that API, not written to the file.
      # The key serves only the image models listed here, at the default
      # priority 0. The quota router gives OAuth accounts priority 100, so
      # Antigravity's free gemini-3.1-flash-image quota is spent first.
      geminiImageModels = [
        "gemini-3.1-flash-image"
        "gemini-3.1-flash-image-preview"
        "gemini-3.1-flash-lite-image"
        "gemini-3-pro-image"
        "gemini-3-pro-image-preview"
        "gemini-2.5-flash-image"
      ];
      geminiKeySync = pkgs.writeShellApplication {
        name = "cliproxyapi-gemini-key-sync";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
          pkgs.coreutils
        ];
        text = ''
          key_file=$1
          base=http://127.0.0.1:8317/v0/management
          key=$(tr -d '\r\n' < "$key_file")
          [ -n "$key" ] || { echo "empty Gemini key file" >&2; exit 1; }
          desired=$(jq -cn --arg k "$key" --argjson m '${builtins.toJSON geminiImageModels}' \
            '[{"api-key": $k, models: [$m[] | {name: ., alias: .}]}]')
          # curl reads the header and body from files so the keys stay out of argv.
          request() {
            curl -fsS --max-time 10 \
              -H @<(printf 'Authorization: Bearer %s\n' "$CLIPROXY_MANAGEMENT_KEY") "$@"
          }
          current=""
          for _ in $(seq 30); do
            if current=$(request "$base/gemini-api-key"); then break; fi
            current=""
            sleep 2
          done
          [ -n "$current" ] || { echo "management API not ready" >&2; exit 1; }
          shape='[.[] | {"api-key": .["api-key"], models: [(.models // [])[] | {name, alias}]}]'
          if [ "$(jq -cS "(.[\"gemini-api-key\"] // []) | $shape" <<<"$current")" = "$(jq -cS "$shape" <<<"$desired")" ]; then
            echo "Gemini key already configured"
            exit 0
          fi
          request -X PUT -H 'Content-Type: application/json' --data-binary @- \
            "$base/gemini-api-key" <<<"$desired" >/dev/null
          echo "Gemini key configured for ${toString (builtins.length geminiImageModels)} image models"
        '';
      };
      unit = {
        inherit environment;
        unitConfig.ConditionPathExists = ready;
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
      };
    in
    {
      options.mountainous.features.cliproxyapi = {
        enable = lib.mkEnableOption "independently deployed CLIProxyAPI application";
        deployPublicKey = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
        signingPublicKey = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
        geminiApiKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Runtime file with a Gemini API key, pushed to the core for image models.";
        };
      };
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.deployPublicKey != "" && cfg.signingPublicKey != "";
            message = "CLIProxyAPI requires the Unzen deployment and signing public keys.";
          }
        ];
        users.groups.cliproxyapi = { };
        users.users.cliproxyapi = {
          isSystemUser = true;
          group = "cliproxyapi";
          home = state;
          createHome = true;
          homeMode = "0700";
          shell = pkgs.bashInteractive;
          hashedPassword = "*";
          openssh.authorizedKeys.keys = [ "restrict ${cfg.deployPublicKey}" ];
        };
        # Signed closure imports avoid granting Nix trusted-user/root access.
        nix.settings.trusted-public-keys = [ cfg.signingPublicKey ];
        environment.systemPackages = [ controller ];
        security.sudo.extraRules = [
          {
            users = [ "cliproxyapi" ];
            commands = [
              {
                command = "${controller}/bin/cliproxyapi-service-control *";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];
        environment.persistence."/tundra/permafrost".directories = [
          {
            directory = state;
            user = "cliproxyapi";
            group = "cliproxyapi";
            mode = "0700";
          }
        ];
        systemd.tmpfiles.rules = [
          "d /nix/var/nix/profiles/per-user/cliproxyapi 0755 cliproxyapi cliproxyapi -"
          "L ${state}/.nix-profile - cliproxyapi cliproxyapi - ${profile}"
        ];
        systemd.services.cliproxyapi = unit // {
          description = "CLIProxyAPI loopback core";
          serviceConfig = common // {
            ExecStart = "${profile}/bin/cli-proxy-api -config ${state}/.config/cliproxyapi/config.yaml";
          };
        };
        systemd.services.cliproxyapi-tsnet = unit // {
          description = "Existing CLIProxyAPI tailnet identity and HTTPS endpoint";
          wants = [
            "network-online.target"
            "cliproxyapi.service"
          ];
          after = [
            "network-online.target"
            "cliproxyapi.service"
          ];
          serviceConfig = common // {
            ExecStart = "${profile}/bin/cliproxyapi-tsnet --name cliproxyapi --state ${state}/.config/cliproxyapi-tsnet --quota-state ${state}/.local/state/cliproxyapi-quota-router/state.json --quota-reset-command ${profile}/bin/cliproxy-quota-router";
          };
        };
        systemd.services.cliproxyapi-quota-router = {
          description = "Observe provider quotas and maintain account routing";
          inherit environment;
          unitConfig.ConditionPathExists = ready;
          wants = [ "cliproxyapi.service" ];
          after = [ "cliproxyapi.service" ];
          serviceConfig = common // {
            Type = "oneshot";
            Restart = "no";
            TimeoutStartSec = 90;
            EnvironmentFile = "${state}/.config/cliproxyapi/quota-router.env";
            ExecStart = "${profile}/bin/cliproxy-quota-router";
          };
        };
        # Runs once per core start. After a key rotation, restart this unit.
        systemd.services.cliproxyapi-gemini-key = lib.mkIf (cfg.geminiApiKeyFile != null) {
          description = "Configure the CLIProxyAPI Gemini API key for image models";
          inherit environment;
          unitConfig.ConditionPathExists = ready;
          wantedBy = [ "cliproxyapi.service" ];
          requires = [ "cliproxyapi.service" ];
          after = [ "cliproxyapi.service" ];
          partOf = [ "cliproxyapi.service" ];
          serviceConfig = common // {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "no";
            TimeoutStartSec = 90;
            EnvironmentFile = "${state}/.config/cliproxyapi/quota-router.env";
            ExecStart = "${geminiKeySync}/bin/cliproxyapi-gemini-key-sync ${cfg.geminiApiKeyFile}";
          };
        };
        systemd.timers.cliproxyapi-quota-router = {
          wantedBy = [ "timers.target" ];
          unitConfig.ConditionPathExists = ready;
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = "2min";
            Unit = "cliproxyapi-quota-router.service";
          };
        };
      };
    };
}
