{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) attrByPath escapeShellArgs mkIf mkMerge optional optionals;
  cfg = config.mountainous.features.dictation-backend;
  tsnetProxyEnabled = attrByPath ["mountainous" "features" "tsnet-proxy" "enable"] false config;
  serviceName = "dictation-backend";
  stateDirectory = "/var/lib/${serviceName}";
  whisperCpp =
    (pkgs.whisper-cpp.override {
      cudaSupport = true;
    }).overrideAttrs (previous: {
      patches =
        (previous.patches or [])
        ++ [
          ./disable-model-load-endpoint.patch
        ];
      # Zao's RTX 3060 Laptop GPU has CUDA compute capability 8.6. Building
      # only that target avoids compiling every architecture in nixpkgs.
      cmakeFlags =
        (previous.cmakeFlags or [])
        ++ [
          (lib.cmakeFeature "CMAKE_CUDA_ARCHITECTURES" "86")
        ];
    });
  command = escapeShellArgs (
    [
      "${whisperCpp}/bin/whisper-server"
      "--model"
      (toString cfg.modelFile)
      "--host"
      "127.0.0.1"
      "--port"
      (toString cfg.port)
      "--language"
      cfg.language
      "--flash-attn"
      "--inference-path"
      "/v1/audio/transcriptions"
    ]
    ++ optionals (cfg.audioContext != null) [
      "--audio-ctx"
      (toString cfg.audioContext)
    ]
  );
in {
  config = mkIf cfg.enable (mkMerge [
    {
      assertions = optional cfg.proxy.enable {
        assertion = tsnetProxyEnabled;
        message = "mountainous.features.dictation-backend.proxy requires mountainous.features.tsnet-proxy.enable = true";
      };

      users.users.${serviceName} = {
        isSystemUser = true;
        group = serviceName;
        extraGroups = [
          "render"
          "video"
        ];
        home = stateDirectory;
        description = "Dictation speech-to-text backend";
      };

      users.groups.${serviceName} = {};

      systemd.services.${serviceName} = {
        description = "Dictation speech-to-text backend";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          Type = "simple";
          User = serviceName;
          Group = serviceName;
          StateDirectory = serviceName;
          StateDirectoryMode = "0700";
          WorkingDirectory = stateDirectory;
          ExecStart = command;
          Restart = "on-failure";
          RestartSec = "5s";
          UMask = "0077";
          MemoryMax = "8G";

          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectHostname = true;
          ProtectClock = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          LockPersonality = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          RemoveIPC = true;
          PrivateMounts = true;
        };
      };
    }

    (mkIf cfg.proxy.enable {
      mountainous.features.tsnet-proxy.services.dictate = {
        host = "127.0.0.1";
        hostname = cfg.proxy.hostname;
        interactiveLogin = true;
        openFirewall = false;
        port = cfg.port;
        protocol = "http";
      };
    })
  ]);
}
