{
  rakku,
  unzen,
  deploy,
  lib,
}:
let
  app = rakku.mountainous.serviceApps.groceries;
  server = rakku.systemd.services.groceries;
  sidecar = rakku.systemd.services.groceries-tsnet;
  path = "/nix/var/nix/profiles/apps/groceries";
  rules = lib.filter (rule: builtins.elem "app-deploy" rule.users) rakku.security.sudo.extraRules;
  commands = lib.filter (lib.hasInfix "/groceries-service-control ") (
    lib.concatMap (rule: map (command: command.command) rule.commands) rules
  );
in
assert app.port == 4382;
assert !app.rollbackCanary;
assert app.package == null;
assert rakku.mountainous.serviceApps.service-app-canary.input == null;
assert rakku.mountainous.serviceApps.service-app-canary.package != null;
assert !(unzen.mountainous.appUpdates ? service-app-canary);
assert !(unzen.systemd.services ? app-update-service-app-canary);
assert rakku.mountainous.serviceApps.service-app-canary.rollbackCanary;
assert !(builtins.elem "--name" rakku.mountainous.serviceApps.service-app-canary.sidecarArgs);
assert rakku.users.users.groceries.isSystemUser;
assert rakku.users.users.groceries.group == "groceries";
assert rakku.users.users.groceries.homeMode == "0700";
assert !builtins.elem "groceries" rakku.nix.settings.trusted-users;
assert server.unitConfig.ConditionPathExists == "${path}/bin/groceries-server";
assert sidecar.unitConfig.ConditionPathExists == "${path}/bin/groceries-tsnet";
assert lib.hasInfix "--host 127.0.0.1 --port 4382" server.serviceConfig.ExecStart;
assert lib.hasInfix path sidecar.serviceConfig.ExecStart;
assert server.serviceConfig.ProtectSystem == "strict";
assert sidecar.serviceConfig.ReadWritePaths == [ "/var/lib/groceries/state/tsnet" ];
assert sidecar.serviceConfig.ReadOnlyPaths == [ "/var/lib/groceries" ];
assert rakku.sops.secrets.groceries-proxy-token.owner == "groceries";
assert rakku.sops.secrets.groceries-proxy-token.mode == "0400";
assert builtins.any (
  entry: entry.directory == "/var/lib/groceries" && entry.mode == "0700"
) rakku.environment.persistence."/tundra/permafrost".directories;
# Impermanence must compose with, not replace, the controller package list.
assert builtins.any (
  package: (package.name or "") == "groceries-service-control"
) rakku.environment.systemPackages;
assert builtins.length commands == 2;
assert lib.all (
  command: lib.hasInfix "groceries-service-control " command && !(lib.hasInfix "*" command)
) commands;
assert deploy.nodes.rakku.profiles.groceries.profilePath == path;
assert !(deploy.nodes.unzen.profiles ? groceries);
assert unzen.mountainous.appUpdates.groceries.hosts == [ "rakku" ];
assert unzen.mountainous.appUpdates.groceries.input == "groceries";
assert
  unzen.systemd.services.app-update-groceries.unitConfig.ConditionPathExists
  == "/var/lib/app-updater/enabled-groceries";
assert
  unzen.systemd.services.app-update-pi.unitConfig.ConditionPathExists
  == "/var/lib/app-updater/enabled";
assert !(builtins.elem "hiyori" unzen.mountainous.appUpdates.pi.hosts);
assert rakku.mountainous.serviceApps.knowledge.port == 4381;
assert
  rakku.mountainous.serviceApps.knowledge.serverArgs == [
    "--data-dir"
    "/var/lib/knowledge/data"
    "--origin"
    "https://knowledge.hummingbird-lake.ts.net"
  ];
assert rakku.sops.secrets.knowledge-pi-cliproxyapi.owner == "knowledge";
assert builtins.any (
  entry: entry.directory == "/var/lib/knowledge" && entry.mode == "0700"
) rakku.environment.persistence."/tundra/permafrost".directories;
assert unzen.mountainous.appUpdates.knowledge.hosts == [ "rakku" ];
assert deploy.nodes.rakku.profiles.knowledge.profilePath == "/nix/var/nix/profiles/apps/knowledge";
assert !(rakku.systemd.services ? groceries-ytdlp-update);
assert lib.all
  (
    name:
    let
      refresh = unzen.systemd.services."${name}-ytdlp-update";
      timer = unzen.systemd.timers."${name}-ytdlp-update";
    in
    refresh.serviceConfig.User == name
    && refresh.serviceConfig.ProtectSystem == "strict"
    && refresh.serviceConfig.ReadWritePaths == [ "/var/lib/${name}" ]
    && refresh.serviceConfig.Type == "oneshot"
    &&
      refresh.unitConfig.ConditionPathExists
      == "/nix/var/nix/profiles/apps/${name}/bin/${name}-ytdlp-update"
    && timer.timerConfig.Persistent
    && timer.timerConfig.OnCalendar == unzen.mountainous.serviceApps.${name}.ytDlpSchedule
  )
  (lib.attrNames (lib.filterAttrs (_: app: app.ytDlpSchedule != null) unzen.mountainous.serviceApps));
true
