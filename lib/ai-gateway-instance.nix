# One instance owns its account, state, credentials, loopback ports and tailnet
# identity. Importing the module does not fetch the package until enabled.
{
  inputs,
  name,
  tailnetName,
  secretPrefix,
  listenPort,
  egressPort,
  loginKeeperSecret,
  usageSecret,
  gatewayKeys,
  description,
  egressDescription,
  tailnetDescription,
}:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.mountainous.features.${name};
  toml = pkgs.formats.toml { };
  state = "/var/lib/${name}";
  credential = credentialName: "/run/credentials/${name}.service/${credentialName}";
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
    http_port 127.0.0.1:${toString egressPort}
    visible_hostname ${name}-egress
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
    memory_cache_shared off
    cache_mem 0 MB
    maximum_object_size 0 KB
    access_log stdio:/run/${name}-egress/access.log
    cache_store_log none
    cache_log /run/${name}-egress/cache.log
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
    restartUnits = [ "${name}.service" ];
  };
  # The existing Gemini image grants now route directly to the paid API.
  # Keep their catalog, grant and ceiling prices on the same reviewed IDs.
  geminiImageModels = [
    "gemini-3.1-flash-image"
    "gemini-3.1-flash-image-preview"
    "gemini-3.1-flash-lite-image"
    "gemini-3-pro-image"
    "gemini-3-pro-image-preview"
    "gemini-2.5-flash-image"
  ];
  # Ceiling, not tariff: each attempted decision reserves this fixed USD
  # charge. Test-b can pay for two Jev calls, but not a third.
  systemoneCharges = {
    jev = 0.004;
    solar = 0.004;
  };
  keys = gatewayKeys geminiImageModels;
  settings = {
    systemone_charges = systemoneCharges;
    listen = "127.0.0.1:${toString listenPort}";
    state_dir = state;
    egress_proxy = "http://127.0.0.1:${toString egressPort}";
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
      map (id: {
        inherit id;
        provider = "gemini";
        input_modalities = [
          "text"
          "image"
        ];
      }) geminiImageModels
      ++ lib.optionals cfg.providers.openrouter.enable [
        {
          id = "deepseek-v4.1-flash";
          provider = "openrouter";
          upstream_model = "deepseek/deepseek-v4.1-flash";
          context_window = 1048576;
          max_tokens = 8192;
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
          context_window = 256000;
          max_tokens = 8192;
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
      # Use the same ceilings for API-equivalent decision usage reporting.
      jev.request = systemoneCharges.jev;
      solar.request = systemoneCharges.solar;
    }
    // lib.genAttrs geminiImageModels (_: {
      image_per_unit = 1.0;
    });
    gateway_keys = map (
      key:
      (lib.removeAttrs key [
        "secret"
        "credential"
      ])
      // {
        key_file = credential key.credential;
      }
    ) keys;
  };
in
{
  options.mountainous.features.${name} = {
    enable = lib.mkEnableOption "the isolated ${name} front door";
    providers = lib.mapAttrs (_: _: {
      enable = lib.mkEnableOption "optional gateway provider (requires its host sops secret)";
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
  config = lib.mkIf cfg.enable {
    mountainous.features.${name} = {
      inherit settings;
      configFile = toml.generate "${name}.toml" settings;
      egressConfigFile = pkgs.writeText "${name}-squid.conf" egressConfig;
    };
    assertions = [
      {
        assertion = config.networking.hostName == "rakku";
        message = "The ${name} placement is Rakku only.";
      }
    ];
    sops.secrets =
      lib.listToAttrs (map (key: lib.nameValuePair key.secret (hostSecret key.secret)) keys)
      // {
        "${usageSecret}" = hostSecret usageSecret;
      }
      // lib.mapAttrs' (
        provider: _:
        lib.nameValuePair "${secretPrefix}-${provider}-api-key" (
          hostSecret "${secretPrefix}-${provider}-api-key"
        )
      ) enabledProviders;
    users.groups.${name} = { };
    users.users.${name} = {
      isSystemUser = true;
      group = name;
    };
    systemd.services.${name} = {
      inherit description;
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      requires = [ "${name}-egress.service" ];
      after = [
        "network-online.target"
        "${name}-egress.service"
      ];
      unitConfig.RequiresMountsFor = [ state ];
      serviceConfig = sandbox // {
        DynamicUser = false;
        # Preserve the IPC cleanup previously implied by DynamicUser.
        RemoveIPC = true;
        User = name;
        Group = name;
        StateDirectory = name;
        StateDirectoryMode = "0700";
        ReadWritePaths = [ state ];
        WorkingDirectory = state;
        IPAddressDeny = [ "any" ];
        IPAddressAllow = [
          "127.0.0.1/32"
          "::1/128"
        ];
        LoadCredential = [
          "login-keeper:${config.sops.secrets.${loginKeeperSecret}.path}"
          "gemini:${config.sops.secrets.cliproxyapi-gemini-api-key.path}"
          "decisions:${config.sops.secrets.litellm-env.path}"
        ]
        ++ map (key: "${key.credential}:${config.sops.secrets.${key.secret}.path}") keys
        ++ [ "usage:${config.sops.secrets.${usageSecret}.path}" ]
        ++ lib.mapAttrsToList (
          name: _: "${name}:${config.sops.secrets."${secretPrefix}-${name}-api-key".path}"
        ) enabledProviders;
        ExecStart = "${
          inputs.ai-gateway.packages.${pkgs.stdenv.hostPlatform.system}.default
        }/bin/ai-gateway-front-door --config ${cfg.configFile}";
      };
    };
    systemd.services."${name}-egress" = {
      description = egressDescription;
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = sandbox // {
        RuntimeDirectory = "${name}-egress";
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = "restart";
        # Squid 7.6 still creates IPC metadata with its memory cache off.
        # Give it a private, bounded POSIX shm mount, never the host's shm.
        ReadOnlyPaths = [
          "/tmp"
          "/var/tmp"
        ];
        TemporaryFileSystem = [ "/dev/shm:rw,nosuid,nodev,noexec,size=16M,mode=1777" ];
        WorkingDirectory = "/run/${name}-egress";
        ExecStart = "${pkgs.squid}/bin/squid -N -f ${cfg.egressConfigFile}";
      };
    };
    # Rakku's shared /var/lib/private is 0755 for existing production state.
    # A static owner avoids DynamicUser's incompatible parent-mode check.
    # Do not change that shared directory or any production state.
    environment.persistence."/tundra/permafrost".directories = [
      {
        directory = "/var/lib/${name}";
        user = name;
        group = name;
        mode = "0700";
      }
    ];
    mountainous.tailnetNames.${tailnetName} = {
      description = tailnetDescription;
      backend = "http://127.0.0.1:${toString listenPort}";
      after = [ "${name}.service" ];
    };
  };
}
