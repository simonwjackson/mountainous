# Inspect the real host configurations, including their existing HA contract.
{ rakku, unzen }:
let
  profile = "/nix/var/nix/profiles/per-user/cliproxyapi/application";
  ready = "/var/lib/cliproxyapi/.migration-ready";
  persistence = map (
    entry: if builtins.isString entry then entry else entry.directory
  ) rakku.environment.persistence."/tundra/permafrost".directories;
  ha = import ./rakku-contract.nix rakku;
in
assert ha.status == "pass";
assert rakku.mountainous.features.cliproxyapi.enable;
assert builtins.all (name: rakku.systemd.services.${name}.unitConfig.ConditionPathExists == ready) [
  "cliproxyapi"
  "cliproxyapi-tsnet"
  "cliproxyapi-quota-router"
];
assert builtins.all
  (
    name:
    builtins.match ".*${profile}/bin/.*" rakku.systemd.services.${name}.serviceConfig.ExecStart != null
  )
  [
    "cliproxyapi"
    "cliproxyapi-tsnet"
    "cliproxyapi-quota-router"
  ];
assert builtins.elem "/var/lib/cliproxyapi" persistence;
assert rakku.users.users.cliproxyapi.isSystemUser;
assert !(builtins.elem "wheel" rakku.users.users.cliproxyapi.extraGroups);
assert !(builtins.elem "cliproxyapi" rakku.nix.settings.trusted-users);
assert builtins.elem rakku.mountainous.features.cliproxyapi.signingPublicKey
  rakku.nix.settings.trusted-public-keys;
assert rakku.systemd.services.cliproxyapi.serviceConfig.NoNewPrivileges;
assert rakku.systemd.services.cliproxyapi-quota-router.serviceConfig.Type == "oneshot";
assert rakku.systemd.timers.cliproxyapi-quota-router.timerConfig.OnUnitActiveSec == "2min";
assert unzen.mountainous.features.cliproxyapi-updater.enable;
assert !(unzen.systemd.services ? cliproxyapi);
assert
  unzen.systemd.services.cliproxyapi-update.serviceConfig.ExecStart
  == "/nix/var/nix/profiles/cliproxyapi-updater/bin/cliproxy-nightly-update";
assert
  unzen.systemd.services.cliproxyapi-update.unitConfig.ConditionPathExists
  == "/var/lib/cliproxyapi-updater/enabled";
assert unzen.systemd.timers.cliproxyapi-update.timerConfig.OnCalendar == "*-*-* 03:00:00 UTC";
assert unzen.systemd.services.cliproxyapi-update.serviceConfig.MemoryMax == "8G";
assert !rakku.system.autoUpgrade.enable;
# The Gemini image key comes from sops, is readable only by the service user,
# and is pushed through the management API after the core starts.
assert rakku.sops.secrets.cliproxyapi-gemini-api-key.owner == "cliproxyapi";
assert rakku.sops.secrets.cliproxyapi-gemini-api-key.mode == "0400";
assert
  rakku.mountainous.features.cliproxyapi.geminiApiKeyFile
  == rakku.sops.secrets.cliproxyapi-gemini-api-key.path;
assert rakku.systemd.services.cliproxyapi-gemini-key.serviceConfig.User == "cliproxyapi";
assert rakku.systemd.services.cliproxyapi-gemini-key.unitConfig.ConditionPathExists == ready;
assert builtins.elem "cliproxyapi.service" rakku.systemd.services.cliproxyapi-gemini-key.after;
# The quota router reads the ElevenLabs credit balance from a systemd
# credential; the secret itself stays root-only.
assert
  rakku.systemd.services.cliproxyapi-quota-router.serviceConfig.LoadCredential == [
    "elevenlabs:${rakku.sops.secrets.elevenlabs-api-key.path}"
  ];
assert rakku.sops.secrets.elevenlabs-api-key.mode == "0400";
{
  status = "pass";
  applicationProfile = profile;
  haExec = ha.haExec;
  zwaveExec = ha.zwaveExec;
  applicationUserIsNotNixTrusted = true;
  requiresMigratedStateBeforeStarting = true;
  builder = "unzen";
  target = "rakku";
}
