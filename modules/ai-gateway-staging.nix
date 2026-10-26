# Separate placement and identity: no production client or login-keeper changes.
{ self, inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      c = self.nixosConfigurations.rakku.config;
      cfg = c.mountainous.features.ai-gateway-staging;
      unit = c.systemd.services.ai-gateway-staging.serviceConfig;
      proxy = c.systemd.services.ai-gateway-staging-egress.serviceConfig;
      want = ok: message: lib.optional (!ok) message;
      problems =
        want (unit.IPAddressDeny == [ "any" ]) "front door must deny all IPs by default"
        ++ want (
          unit.IPAddressAllow == [
            "127.0.0.1/32"
            "::1/128"
          ]
        ) "front door allows non-loopback IPs"
        ++ want unit.DynamicUser "front door must use DynamicUser"
        ++ want (cfg.settings.listen == "127.0.0.1:8420") "front door listens beyond IPv4 loopback"
        ++ want (cfg.settings.egress_proxy == "http://127.0.0.1:8421") "missing egress proxy"
        ++ want (proxy.DynamicUser && proxy.ProtectSystem == "strict") "egress proxy is not sandboxed"
        ++ want (
          c.mountainous.tailnetNames.ai-staging.backend == "http://127.0.0.1:8420"
        ) "wrong tailnet backend"
        ++ want (
          !(lib.hasInfix "cors" (lib.toLower (builtins.toJSON cfg.settings)))
        ) "CORS config is forbidden";
    in
    {
      checks.ai-gateway-staging =
        if problems != [ ] then
          throw "ai-gateway-staging:\n  ${lib.concatStringsSep "\n  " problems}"
        else
          pkgs.runCommand "ai-gateway-staging"
            {
              nativeBuildInputs = [
                pkgs.python3
                pkgs.squid
              ];
            }
            ''
              export HOME=$TMPDIR
              python3 ${../tests/ai-gateway-staging.py} ${cfg.egressConfigFile} ${cfg.configFile}
              python3 ${../tests/ai-gateway-staging-diff.py} ${../scripts/check-ai-staging-rakku}
              touch $out
            '';
    };

  nixos.modules.ai-gateway-staging =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.mountainous.features.ai-gateway-staging;
      toml = pkgs.formats.toml { };
      state = "/var/lib/ai-gateway-staging";
      credential = name: "/run/credentials/ai-gateway-staging.service/${name}";
      providerHosts = [
        "api.elevenlabs.io"
        "api.x.ai"
        "openrouter.ai"
        # LiteLLM typesafe/decisions/transformation.py: get_default_api_base.
        "api.typesafe.ai"
        "api.upstage.ai"
        "generativelanguage.googleapis.com"
      ];
      # Reject private/reserved destinations even when an allowed name resolves
      # there. -n on dstdomain also prevents reverse-DNS approval of IP literals.
      nonPublic = [
        "0.0.0.0/8"
        "10.0.0.0/8"
        "100.64.0.0/10"
        "127.0.0.0/8"
        "169.254.0.0/16"
        "172.16.0.0/12"
        "192.0.0.0/24"
        "192.0.2.0/24"
        "192.168.0.0/16"
        "198.18.0.0/15"
        "198.51.100.0/24"
        "203.0.113.0/24"
        "224.0.0.0/4"
        "240.0.0.0/4"
        "::/128"
        "::1/128"
        "64:ff9b::/96"
        "64:ff9b:1::/48"
        "100::/64"
        "fc00::/7"
        "fec0::/10"
        "fe80::/10"
        "ff00::/8"
        "2001:db8::/32"
      ];
      egressConfig = ''
        http_port 127.0.0.1:8421
        visible_hostname ai-gateway-staging-egress
        acl loopback_client src 127.0.0.1/32
        acl connect_method method CONNECT
        acl tls_port port 443
        acl provider dstdomain -n ${lib.concatStringsSep " " providerHosts}
        acl non_public dst ${lib.concatStringsSep " " nonPublic}
        http_access deny !loopback_client
        http_access deny !connect_method
        http_access deny !tls_port
        http_access deny !provider
        http_access deny non_public
        http_access allow loopback_client connect_method tls_port provider
        http_access deny all
        cache deny all
        cache_mem 8 MB
        maximum_object_size 0 KB
        access_log none
        cache_store_log none
        cache_log /dev/stderr
        pid_filename none
        shutdown_lifetime 1 seconds
        forwarded_for delete
      '';
      # Shared sandbox; /tmp is private AND read-only. The front door's only
      # writable persistent path is StateDirectory, not any source secret.
      sandbox = {
        DynamicUser = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadOnlyPaths = [
          "/tmp"
          "/var/tmp"
          "/dev/shm"
        ];
        PrivateDevices = true;
        NoNewPrivileges = true;
        CapabilityBoundingSet = "";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        SystemCallFilter = [ "@system-service" ];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        UMask = "0077";
        MemoryMax = "512M";
        Restart = "on-failure";
        RestartSec = 5;
      };
      optionalProviders = {
        elevenlabs = "https://api.elevenlabs.io";
        xai = "https://api.x.ai";
        openrouter = "https://openrouter.ai/api";
      };
      enabledProviders = lib.filterAttrs (name: _: cfg.providers.${name}.enable) optionalProviders;
      hostSecret = key: {
        sopsFile = ../secrets/hosts/rakku.yaml;
        inherit key;
        mode = "0400";
        restartUnits = [ "ai-gateway-staging.service" ];
      };
      settings = {
        listen = "127.0.0.1:8420";
        state_dir = state;
        egress_proxy = "http://127.0.0.1:8421";
        login_keeper = {
          url = "http://127.0.0.1:8317";
          key_file = credential "login-keeper";
        };
        usage.key_file = credential "usage";
        # Plan-share estimates, not metered subscription spend.
        plan_prices = {
          claude = 200.0;
          codex = 200.0;
          antigravity = 20.0;
        };
        image_fallback.model = "gemini-3.1-flash-image";
        providers = {
          gemini = {
            base_url = "https://generativelanguage.googleapis.com";
            key_file = credential "gemini";
          };
          typesafe = {
            base_url = "https://api.typesafe.ai";
            env_file = credential "decisions";
            env_var = "TYPESAFE_API_KEY";
          };
          upstage = {
            base_url = "https://api.upstage.ai";
            env_file = credential "decisions";
            env_var = "UPSTAGE_API_KEY";
          };
        }
        // lib.mapAttrs (name: base_url: {
          inherit base_url;
          key_file = credential name;
        }) enabledProviders;
        paid_models =
          lib.optionals cfg.providers.openrouter.enable [
            {
              id = "deepseek-v4.1-flash";
              provider = "openrouter";
              upstream_model = "deepseek/deepseek-v4.1-flash";
            }
          ]
          ++ lib.optionals cfg.providers.elevenlabs.enable [
            {
              id = "eleven_multilingual_v2";
              provider = "elevenlabs";
            }
          ]
          ++ lib.optionals cfg.providers.xai.enable [
            {
              id = "grok-4";
              provider = "xai";
            }
            {
              id = "grok-tts";
              provider = "xai";
            }
          ];
        # Ceiling, not tariff: deliberately high staging charges bound tests.
        # Reconcile against verified tariffs before any production cutover.
        prices = {
          "deepseek-v4.1-flash" = {
            input_per_million = 10.0;
            output_per_million = 50.0;
          };
          "grok-4" = {
            input_per_million = 10.0;
            output_per_million = 50.0;
          };
          "eleven_multilingual_v2".audio_per_million_characters = 500.0;
          "grok-tts".audio_per_million_characters = 500.0;
          jev.request = 0.005;
          solar = {
            input_per_million = 1.0;
            output_per_million = 1.0;
            request = 0.01;
          };
          "gemini-3.1-flash-image".image_per_unit = 1.0;
        };
        gateway_keys = [
          {
            name = "ai-staging-test-a";
            key_file = credential "test-a";
            models = [
              "claude-opus-5-5"
              "gpt-6.1-sol"
              "gemini-3.8-flash-high"
              "deepseek-v4.1-flash"
              "jev"
              "solar"
              "fast"
              "gemini-3.1-flash-image"
              "gemini-3.1-flash-image-preview"
              "gemini-3.1-flash-lite-image"
              "gemini-3-pro-image"
              "gemini-3-pro-image-preview"
              "gemini-2.5-flash-image"
              "eleven_multilingual_v2"
              "grok-tts"
            ];
            dialects = [
              "codex"
              "responses"
              "chat_completions"
              "messages"
              "speech"
              "images"
              "systemone"
              "models"
              "quota"
            ];
            monthly_cap_usd = 2.0;
            requests_per_minute = 10;
          }
          {
            name = "ai-staging-test-b";
            key_file = credential "test-b";
            # Parent-approved deviation: existing paid chat keys are unavailable.
            # Two Jev decisions at the staging ceiling exhaust this cap.
            models = [ "jev" ];
            dialects = [ "systemone" ];
            monthly_cap_usd = 0.01;
            requests_per_minute = 10;
          }
        ];
      };
    in
    {
      options.mountainous.features.ai-gateway-staging = {
        providers = lib.mapAttrs (_: _: {
          enable = lib.mkEnableOption "optional staging provider (requires its host sops secret)";
        }) optionalProviders;
        settings = lib.mkOption {
          inherit (toml) type;
          readOnly = true;
          internal = true;
        };
        configFile = lib.mkOption {
          type = lib.types.path;
          readOnly = true;
          internal = true;
        };
        egressConfigFile = lib.mkOption {
          type = lib.types.path;
          readOnly = true;
          internal = true;
        };
      };
      config = {
        mountainous.features.ai-gateway-staging = {
          inherit settings;
          configFile = toml.generate "ai-gateway-staging.toml" settings;
          egressConfigFile = pkgs.writeText "ai-gateway-staging-squid.conf" egressConfig;
        };
        assertions = [
          {
            assertion = config.networking.hostName == "rakku";
            message = "The AI staging placement is Rakku only.";
          }
        ];
        sops.secrets = {
          ai-staging-test-a = hostSecret "ai-staging-test-a";
          ai-staging-test-b = hostSecret "ai-staging-test-b";
          ai-staging-usage = hostSecret "ai-staging-usage";
          # Separate declaration: do not change ownership/restarts of Pi's key.
          ai-staging-login-keeper = {
            sopsFile = ../secrets/fleet.yaml;
            key = "pi-cliproxyapi-api-key";
            mode = "0400";
            restartUnits = [ "ai-gateway-staging.service" ];
          };
        }
        // lib.mapAttrs' (
          name: _: lib.nameValuePair "ai-staging-${name}-api-key" (hostSecret "ai-staging-${name}-api-key")
        ) enabledProviders;
        systemd.services.ai-gateway-staging = {
          description = "AI gateway staging front door (no production cutover)";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          requires = [ "ai-gateway-staging-egress.service" ];
          after = [
            "network-online.target"
            "ai-gateway-staging-egress.service"
          ];
          unitConfig.RequiresMountsFor = [ state ];
          serviceConfig = sandbox // {
            StateDirectory = "ai-gateway-staging";
            StateDirectoryMode = "0700";
            ReadWritePaths = [ state ];
            WorkingDirectory = state;
            IPAddressDeny = [ "any" ];
            IPAddressAllow = [
              "127.0.0.1/32"
              "::1/128"
            ];
            LoadCredential = [
              "login-keeper:${config.sops.secrets.ai-staging-login-keeper.path}"
              "gemini:${config.sops.secrets.cliproxyapi-gemini-api-key.path}"
              "decisions:${config.sops.secrets.litellm-env.path}"
              "test-a:${config.sops.secrets.ai-staging-test-a.path}"
              "test-b:${config.sops.secrets.ai-staging-test-b.path}"
              "usage:${config.sops.secrets.ai-staging-usage.path}"
            ]
            ++ lib.mapAttrsToList (
              name: _: "${name}:${config.sops.secrets."ai-staging-${name}-api-key".path}"
            ) enabledProviders;
            ExecStart = "${
              inputs.ai-gateway.packages.${pkgs.stdenv.hostPlatform.system}.default
            }/bin/ai-gateway-front-door --config ${cfg.configFile}";
          };
        };
        systemd.services.ai-gateway-staging-egress = {
          description = "Staging-only provider hostname allowlisting CONNECT proxy";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          serviceConfig = sandbox // {
            RuntimeDirectory = "ai-gateway-staging-egress";
            WorkingDirectory = "/run/ai-gateway-staging-egress";
            ExecStart = "${pkgs.squid}/bin/squid -N -f ${cfg.egressConfigFile}";
          };
        };
        # DynamicUser state lives below private/ on the tmpfs-root host. Persist
        # that backing directory, not systemd's public symlink to it.
        environment.persistence."/tundra/permafrost".directories = [
          {
            directory = "/var/lib/private/ai-gateway-staging";
            mode = "0700";
          }
        ];
        mountainous.tailnetNames.ai-staging = {
          description = "AI staging tailnet proxy";
          backend = "http://127.0.0.1:8420";
          after = [ "ai-gateway-staging.service" ];
        };
      };
    };
}
