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
assert rakku.mountainous.serviceApps.service-app-single-canary.sidecar == null;
assert
  rakku.mountainous.serviceApps.service-app-single-canary.unitNames
  == [ "service-app-single-canary.service" ];
assert !(rakku.systemd.services ? service-app-single-canary-tsnet);
assert
  rakku.systemd.services.service-app-single-canary.serviceConfig.ExecStart
  == "/nix/var/nix/profiles/apps/service-app-single-canary/bin/service-app-single-canary-server --host 127.0.0.1 --port 4400";
assert rakku.users.users.service-app-single-canary.isSystemUser;
assert rakku.systemd.services.service-app-single-canary.serviceConfig.ProtectSystem == "strict";
assert
  rakku.environment.etc."service-apps/service-app-single-canary.json".text
  == ''["service-app-single-canary.service"]'';
assert !(unzen.mountainous.appUpdates ? service-app-single-canary);
assert builtins.any (
  rule:
  builtins.elem "app-deploy" rule.users
  && builtins.any (
    command: lib.hasInfix "/service-app-single-canary-service-control start" command.command
  ) rule.commands
) rakku.security.sudo.extraRules;
assert
  rakku.mountainous.serviceApps.groceries.unitNames == [
    "groceries.service"
    "groceries-tsnet.service"
  ];
assert rakku.mountainous.serviceApps.storia.port == 4390;
assert
  rakku.systemd.services.storia.environment.STORIA_CLIPROXY_URL
  == "https://ai.hummingbird-lake.ts.net";
assert rakku.sops.secrets.storia-jev-key.owner == "storia";
assert unzen.mountainous.appUpdates.storia.hosts == [ "rakku" ];
assert rakku.mountainous.serviceApps.meetings.port == 8179;
assert rakku.mountainous.serviceApps.meetings.serverArgs == [ ];
assert rakku.systemd.services.meetings.environment.MEETINGS_DATA_DIR == "/var/lib/meetings/data";
assert unzen.mountainous.appUpdates.meetings.hosts == [ "rakku" ];
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
assert builtins.elem "d /var/lib/youtube/.config 0700 youtube youtube -"
  unzen.systemd.tmpfiles.rules;
assert builtins.elem "d /var/lib/youtube/.config/youtube 0700 youtube youtube -"
  unzen.systemd.tmpfiles.rules;
assert unzen.mountainous.serviceApps.pyxis.server == "pyxis";
assert unzen.mountainous.serviceApps.pyxis.port == 4488;
assert unzen.mountainous.serviceApps.pyxis.environment.PYXIS_STATE_DIR == "/var/lib/pyxis/data";
assert
  unzen.mountainous.serviceApps.pyxis.environment.PYXIS_YT_DLP_DATA_DIR
  == "/var/lib/pyxis/data/yt-dlp";
assert builtins.elem 9000 unzen.networking.firewall.interfaces.bond0.allowedTCPPorts;
assert
  unzen.mountainous.serviceApps.ossicle.environment.OSSICLE_ALLOWED_ORIGINS
  == "https://vela.hummingbird-lake.ts.net";
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
