{ flake, lib }:
let
  host = flake.nixosConfigurations.rakku;
  c = host.config;
  cfg = c.mountainous.features.pi-assistant;
  enabled =
    (host.extendModules {
      modules = [ { mountainous.features.pi-assistant.atlas.enable = lib.mkForce true; } ];
    }).config;
  rotations = lib.concatMap (s: s.restartUnits or [ ]) (
    lib.attrValues c.sops.secrets ++ lib.attrValues c.sops.templates
  );
in
assert cfg.atlas != null && !(cfg.atlas.enable or true);
assert !c.systemd.services.atlas.enable;
assert c.systemd.services.atlas.wantedBy == [ ];
assert !(c.systemd.units."atlas.service".enable or false);
assert !(lib.elem "atlas.service" rotations);
assert lib.all (apps: lib.all (app: app.id != "atlas") apps) (lib.attrValues cfg.mcpServers);
assert c.users.users.pi-atlas.isSystemUser;
assert c.users.users.pi-atlas.group == "pi-atlas";
assert c.users.users.pi-atlas.home == "/var/lib/atlas";
assert c.users.groups ? pi-atlas;
assert lib.any (
  d:
  !builtins.isString d
  && d.directory == "/var/lib/atlas"
  && d.user == "pi-atlas"
  && d.group == "pi-atlas"
  && d.mode == "0700"
) c.environment.persistence."/tundra/permafrost".directories;
assert c.fileSystems."/var/lib/atlas".device == "/tundra/permafrost/var/lib/atlas";
assert enabled.systemd.services.atlas.enable;
assert enabled.systemd.units."atlas.service".enable;
assert lib.elem "multi-user.target" enabled.systemd.services.atlas.wantedBy;
assert lib.any (app: app.id == "atlas") enabled.mountainous.features.pi-assistant.mcpServers.simon;
assert
  !(lib.any (app: app.id == "atlas") enabled.mountainous.features.pi-assistant.mcpServers.household);
true
