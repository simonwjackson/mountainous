{ rakku, lib }:
let
  cfg = rakku.services.sparkyfitness;
  vhost = rakku.services.nginx.virtualHosts.${cfg.nginx.virtualHost};
  frontendPort = rakku.mountainous.features.sparkyfitness.frontendPort;
  memoryMax = rakku.systemd.services.sparkyfitness.serviceConfig.MemoryMax or null;
  persisted = map (p: p.directory) rakku.environment.persistence."/tundra/permafrost".directories;
  retired = [
    "logbook.service"
    "logbook-tsnet.service"
  ];
  units = lib.concatMap lib.attrValues [
    rakku.systemd.services
    rakku.systemd.targets
    rakku.systemd.timers
    rakku.systemd.paths
    rakku.systemd.sockets
  ];
  activated =
    lib.mapAttrsToList (name: unit: unit.timerConfig.Unit or "${name}.service") rakku.systemd.timers
    ++ lib.mapAttrsToList (name: unit: unit.pathConfig.Unit or "${name}.service") rakku.systemd.paths
    ++ lib.mapAttrsToList (
      name: unit: unit.socketConfig.Service or "${name}.service"
    ) rakku.systemd.sockets;
  startsRetired =
    unit: lib.any (name: lib.elem name ((unit.wants or [ ]) ++ (unit.requires or [ ]))) retired;
in
assert cfg.enable;
assert vhost.listen != [ ];
assert lib.all (
  l:
  lib.elem l.addr [
    "127.0.0.1"
    "::1"
  ]
  && l.port == frontendPort
  && !l.ssl
  && !lib.elem "default_server" l.extraParameters
) vhost.listen;
assert !vhost.default;
assert memoryMax != null && memoryMax != "";
assert rakku.systemd.services.sparkyfitness.environment.SPARKY_FITNESS_DISABLE_SIGNUP == "true";
assert lib.elem (toString cfg.stateDir) persisted;
assert lib.elem rakku.services.postgresql.dataDir persisted;
assert rakku.users.users.sparkyfitness.uid == 950 && rakku.users.groups.sparkyfitness.gid == 950;
assert rakku.users.users.postgres.uid == 71 && rakku.users.groups.postgres.gid == 71;
assert
  rakku.mountainous.tailnetNames.sparkyfitness.backend == "http://127.0.0.1:${toString frontendPort}";
assert cfg.frontendUrl == "https://sparkyfitness.hummingbird-lake.ts.net";
# Preset workouts must keep equipment, or the web plate calculator is hidden.
assert lib.any (p: baseNameOf p == "preset-equipment.patch") (cfg.frontendPackage.patches or [ ]);
assert !lib.elem "multi-user.target" rakku.systemd.services.logbook.wantedBy;
assert rakku.systemd.services.logbook-tsnet.wantedBy == [ ];
assert rakku.systemd.services.logbook.unitConfig.RefuseManualStart;
assert rakku.systemd.services.logbook-tsnet.unitConfig.RefuseManualStart;
assert !lib.any startsRetired units;
assert !lib.any (name: lib.elem name retired) activated;
assert rakku.sops.templates."logbook-oura-client.json".restartUnits == [ ];
assert rakku.sops.templates."logbook-withings-client.json".restartUnits == [ ];
# The cached backend binds wildcard; Rakku trusts both LAN and tailscale.
assert rakku.networking.firewall.enable && !rakku.networking.nftables.enable;
assert lib.elem "firewall.service" rakku.systemd.services.sparkyfitness.bindsTo;
assert lib.elem "firewall.service" rakku.systemd.services.sparkyfitness.after;
assert lib.elem "firewall.service" rakku.systemd.services.sparkyfitness.partOf;
assert lib.hasInfix "hook input priority -10" rakku.networking.firewall.extraCommands;
assert lib.hasInfix
  ''add rule inet sparkyfitness input iifname != "lo" tcp dport ${toString cfg.port} reject''
  rakku.networking.firewall.extraCommands;
true
