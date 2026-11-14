{ flake, lib }:
let
  host = flake.nixosConfigurations.rakku;
  c = host.config;
  cfg = c.mountainous.features.pi-assistant;
  runtime =
    map (name: "pi-assistant-${name}") [
      "simon"
      "laure"
      "household"
    ]
    ++ [ "assistant-tsgo" ];
  rotations = lib.concatMap (secret: secret.restartUnits or [ ]) (
    lib.attrValues c.sops.secrets ++ lib.attrValues c.sops.templates
  );
  enabled =
    (host.extendModules {
      modules = [ { mountainous.features.pi-assistant.instances.enable = lib.mkForce true; } ];
    }).config;
  paths = map (
    entry: if builtins.isString entry then entry else entry.directory
  ) c.environment.persistence."/tundra/permafrost".directories;
in
assert !(cfg.instances.enable or true);
assert lib.all (name: !(c.systemd.services.${name}.enable or true)) runtime;
assert lib.all (name: c.systemd.services.${name}.wantedBy == [ ]) runtime;
assert lib.all (name: !(c.systemd.units."${name}.service".enable or false)) runtime;
assert lib.all (name: !(lib.elem "${name}.service" rotations)) runtime;
assert lib.all (name: enabled.systemd.services.${name}.enable) runtime;
assert lib.all (name: enabled.systemd.units."${name}.service".enable) runtime;
assert !(c.systemd.services.signal-responder.enable or true);
assert c.systemd.services.signal-responder.wantedBy == [ ];
assert !(lib.elem "signal-responder.service" rotations);
assert enabled.systemd.services.signal-responder.enable;
assert lib.all
  (
    app:
    let
      unit = c.systemd.services."assistant-app-simon-${app}";
    in
    unit.enable
    && lib.elem "multi-user.target" unit.wantedBy
    && !(lib.any (
      name:
      lib.elem "${name}.service" (
        unit.partOf ++ unit.bindsTo ++ unit.requires ++ unit.wants ++ unit.after
      )
    ) runtime)
  )
  [
    "google"
    "maps"
  ];
assert lib.all (path: lib.elem path paths) [
  "/var/lib/pi-assistant-simon"
  "/var/lib/pi-assistant-laure"
  "/var/lib/pi-assistant-household"
  "/var/lib/pi-household-notebook"
  "/var/lib/assistant-tsgo"
  "/var/lib/signal-responder"
];
assert lib.elem "d /nix/var/nix/profiles/per-user/pi-assistant 0755 root root -"
  c.systemd.tmpfiles.rules;
assert
  c.systemd.services.assistant-app-simon-google.serviceConfig.ExecStart
  == "/nix/var/nix/profiles/per-user/pi-assistant/application/bin/google";
assert
  c.systemd.services.assistant-app-simon-maps.serviceConfig.ExecStart
  == "/nix/var/nix/profiles/per-user/pi-assistant/application/bin/maps";
assert lib.elem "assistant-app-simon-google.service"
  c.sops.secrets.ai-gateway-key-assistant-rakku.restartUnits;
true
