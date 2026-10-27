# Shared invariants for independently placed gateway instances.
{
  self,
  name,
  tailnetName,
  secretPrefix,
  listenPort,
  egressPort,
  testMode,
}:
{ pkgs, lib, ... }:
let
  c = self.nixosConfigurations.rakku.config;
  cfg = c.mountainous.features.${name};
  piHosts = lib.filter (
    host: self.nixosConfigurations.${host}.config.mountainous.appProfiles.pi.enable or false
  ) (lib.attrNames self.nixosConfigurations);
  # Optional paid chat must also satisfy the binary's startup contract,
  # even though those providers are disabled in this placement.
  optionalModels =
    (self.nixosConfigurations.rakku.extendModules {
      modules = [
        {
          mountainous.features.${name}.providers = {
            openrouter.enable = true;
            xai.enable = true;
          };
        }
      ];
    }).config.mountainous.features.${name}.settings.paid_models;
  disabled =
    (self.nixosConfigurations.rakku.extendModules {
      modules = [ { mountainous.features.${name}.enable = lib.mkForce false; } ];
    }).config;
  unit = c.systemd.services.${name}.serviceConfig;
  proxy = c.systemd.services."${name}-egress".serviceConfig;
  want = ok: message: lib.optional (!ok) message;
  problems =
    want cfg.enable "Rakku must explicitly enable the gateway feature"
    ++ want (
      !self.nixosConfigurations.rakku.options.mountainous.features.${name}.enable.default
    ) "gateway feature must default off"
    ++ want (lib.all (name: !(builtins.hasAttr name disabled.systemd.services)) [
      name
      "${name}-egress"
      "tsnet-proxy-${tailnetName}"
    ]) "disabled feature still declares gateway services"
    ++ want (
      !(builtins.hasAttr name disabled.users.users) && !(builtins.hasAttr name disabled.users.groups)
    ) "disabled feature still declares its static account"
    ++ want (
      !(builtins.hasAttr tailnetName disabled.mountainous.tailnetNames)
    ) "disabled feature still declares a tailnet name"
    ++ want (
      !(lib.any (name: lib.hasPrefix "${secretPrefix}-" name) (lib.attrNames disabled.sops.secrets))
    ) "disabled feature still declares gateway secrets"
    ++ want (
      !(lib.any (
        entry:
        lib.elem (if builtins.isString entry then entry else entry.directory) [
          "/var/lib/${name}"
          "/var/lib/private/${name}"
          "/var/lib/tsnet-proxy-${tailnetName}"
        ]
      ) disabled.environment.persistence."/tundra/permafrost".directories)
    ) "disabled feature still persists gateway state"
    ++ want (unit.IPAddressDeny == [ "any" ]) "front door must deny all IPs by default"
    ++ want (
      unit.IPAddressAllow == [
        "127.0.0.1/32"
        "::1/128"
      ]
    ) "front door allows non-loopback IPs"
    ++ want (lib.all (
      model:
      lib.elem model.provider [
        "gemini"
        "elevenlabs"
      ]
      || model.id == "grok-tts"
      || (model.context_window or 0) > 0
    ) optionalModels) "paid chat models require a positive context_window for cap reservations"
    ++ want (
      !unit.DynamicUser
      && unit.RemoveIPC
      && unit.User == name
      && unit.Group == name
      && c.users.users.${name}.isSystemUser
      && c.users.users.${name}.group == name
      && c.users.groups.${name}.gid != 0
      && c.users.users.${name}.uid != 0
    ) "front door must use its static non-root system user and group"
    ++ want (
      unit.StateDirectory == name
      && unit.StateDirectoryMode == "0700"
      && unit.ReadWritePaths == [ "/var/lib/${name}" ]
      && lib.any (
        entry:
        !(builtins.isString entry)
        && entry.directory == "/var/lib/${name}"
        && entry.user == name
        && entry.group == name
        && entry.mode == "0700"
      ) c.environment.persistence."/tundra/permafrost".directories
    ) "front door state must be private and persisted with its static owner"
    ++ want (lib.all
      (
        service:
        service.ProtectSystem == "strict"
        && lib.all (key: service.${key}) [
          "ProtectHome"
          "PrivateTmp"
          "PrivateDevices"
          "NoNewPrivileges"
          "ProtectKernelTunables"
          "ProtectKernelModules"
          "ProtectKernelLogs"
          "ProtectControlGroups"
          "RestrictSUIDSGID"
          "RestrictRealtime"
          "RestrictNamespaces"
          "LockPersonality"
        ]
        && service.UMask == "0077"
        && service.CapabilityBoundingSet == ""
        &&
          service.RestrictAddressFamilies == [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ]
        && service.SystemCallFilter == [ "@system-service" ]
        && service.MemoryMax == "512M"
        && lib.all (path: lib.elem path service.ReadOnlyPaths) [
          "/tmp"
          "/var/tmp"
        ]
      )
      [
        unit
        proxy
      ]
    ) "gateway service sandbox protections changed"
    ++ want (
      cfg.settings.listen == "127.0.0.1:${toString listenPort}"
    ) "front door listens beyond IPv4 loopback"
    ++ want (
      cfg.settings.egress_proxy == "http://127.0.0.1:${toString egressPort}"
    ) "missing egress proxy"
    ++ want (
      lib.elem "/dev/shm" unit.ReadOnlyPaths
      && proxy.DynamicUser
      && proxy.RuntimeDirectoryMode == "0700"
      && proxy.TemporaryFileSystem == [ "/dev/shm:rw,nosuid,nodev,noexec,size=16M,mode=1777" ]
      && !(lib.elem "/dev/shm" proxy.ReadOnlyPaths)
    ) "egress shared memory must be private, writable and bounded"
    ++ want (
      c.mountainous.tailnetNames.${tailnetName}.backend == "http://127.0.0.1:${toString listenPort}"
    ) "wrong tailnet backend"
    ++ want (
      !(lib.hasInfix "cors" (lib.toLower (builtins.toJSON cfg.settings)))
    ) "CORS config is forbidden"
    ++ lib.optionals (testMode == "production") (
      lib.concatMap (
        host:
        let
          client = self.nixosConfigurations.${host}.config.sops.secrets.pi-ai-gateway-api-key;
          gateway = c.sops.secrets."ai-gateway-key-pi-${host}";
        in
        want (
          client.owner == "simon"
          && client.mode == "0400"
          && client.key == gateway.key
          && client.sopsFile == ../secrets/hosts/${host}.yaml
          && gateway.sopsFile == ../secrets/hosts/rakku.yaml
        ) "${host}: Pi must read its own private host key, matched to its production grant"
      ) piHosts
      ++
        lib.concatMap
          (
            key:
            let
              secret = c.sops.secrets.${key};
            in
            want (
              secret.restartUnits == [ "ai-gateway.service" ]
              && secret.mode == "0400"
              && secret.owner == null
              && secret.uid == 0
              && lib.elem "${lib.removePrefix "ai-gateway-key-" key}:${secret.path}" unit.LoadCredential
            ) "${key}: production client credential needs private LoadCredential and rotation restart"
          )
          (
            [
              "ai-gateway-key-storia-zao"
              "ai-gateway-key-korri-zao"
              "ai-gateway-key-pi-zao"
            ]
            ++ map (host: "ai-gateway-key-pi-${host}") piHosts
          )
      ++ want (
        cfg.providers.elevenlabs.enable && !cfg.providers.xai.enable && !cfg.providers.openrouter.enable
      ) "ElevenLabs must be the only enabled speech provider; xAI and OpenRouter stay off"
      ++
        want
          (
            lib.elem "elevenlabs:${c.sops.secrets.elevenlabs-api-key.path}" unit.LoadCredential
            && lib.elem "voice-zao:${c.sops.secrets.ai-gateway-key-voice-zao.path}" unit.LoadCredential
            && c.sops.secrets.elevenlabs-api-key.restartUnits == [ "ai-gateway.service" ]
            && c.sops.secrets.ai-gateway-key-voice-zao.restartUnits == [ "ai-gateway.service" ]
            && c.sops.secrets.ai-gateway-key-voice-zao.mode == "0400"
          )
          "production speech credentials must use existing ElevenLabs and private voice secrets with rotation hooks"
    );
in
{
  checks.${name} =
    if problems != [ ] then
      throw "${name}:\n  ${lib.concatStringsSep "\n  " problems}"
    else
      pkgs.runCommand name
        {
          nativeBuildInputs = [
            pkgs.python3
            pkgs.squid
          ];
        }
        ''
          export HOME=$TMPDIR
          python3 ${../tests/ai-gateway-staging.py} ${cfg.egressConfigFile} ${cfg.configFile} ${testMode} ${lib.escapeShellArg (builtins.toJSON piHosts)}
          python3 ${../tests/ai-gateway-staging-diff.py} ${../scripts/check-ai-staging-rakku}
          touch $out
        '';
}
