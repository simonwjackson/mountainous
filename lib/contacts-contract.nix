# One service identity and writer across the fleet, independent of placement.
{ lib }:
configurations:
let
  enabled = lib.filterAttrs (
    _: system: system.config.mountainous.features.contacts.enable or false
  ) configurations;
  writers = lib.concatLists (
    lib.mapAttrsToList (
      host: system:
      lib.mapAttrsToList (name: _: "${host}:${name}") (
        lib.filterAttrs (
          _: unit:
          let
            command = unit.serviceConfig.ExecStart or "";
          in
          builtins.isString command && lib.hasInfix "/bin/contacts serve" command
        ) system.config.systemd.services
      )
    ) enabled
  );
  want = ok: message: lib.optional (!ok) message;
in
want (lib.length (lib.attrNames enabled) <= 1) "contacts has more than one placement"
++ want (
  lib.length writers == lib.length (lib.attrNames enabled)
) "contacts must have exactly one non-template writer per placement"
++ lib.concatLists (
  lib.mapAttrsToList (
    host: system:
    let
      c = system.config;
      cfg = c.mountainous.features.contacts;
      unit = c.systemd.services.contacts;
      sc = unit.serviceConfig;
      state = "/var/lib/contacts";
      secret = c.sops.secrets.contacts-password;
      persisted = c.environment.persistence."/tundra/permafrost".directories or [ ];
      hostWant = ok: message: want ok "${host}: ${message}";
    in
    hostWant (lib.hasPrefix "127.0.0.1:" cfg.listen) "contacts must listen on IPv4 loopback"
    ++ hostWant (
      sc.ExecStart
      == "${lib.getExe cfg.package} serve --listen ${cfg.listen} --data-dir ${state} --username simon --password-file %d/contacts-password"
    ) "contacts command must keep its loopback bind, state, login and credential"
    ++ hostWant (
      sc.LoadCredential == [ "contacts-password:${secret.path}" ]
      && secret.owner == "root"
      && secret.group == "root"
      && secret.mode == "0400"
      && lib.elem "contacts.service" secret.restartUnits
    ) "contacts password must be a root-only, rotation-aware systemd credential"
    ++ hostWant (
      sc.StateDirectory == "contacts"
      && sc.StateDirectoryMode == "0700"
      && sc.User == "contacts"
      && sc.Group == "contacts"
      && sc.UMask == "0077"
      && lib.elem state unit.unitConfig.RequiresMountsFor
    ) "contacts must own its private systemd state directory"
    ++ hostWant (lib.any (
      entry:
      !builtins.isString entry
      && entry.directory == state
      && entry.user == "contacts"
      && entry.group == "contacts"
      && entry.mode == "0700"
    ) persisted) "contacts service state must survive Rakku's tmpfs root"
    ++ hostWant (
      writers == [ "${host}:contacts" ]
    ) "contacts must be a singleton unit, not a template or second writer"
    ++ hostWant (
      (c.mountainous.tailnetNames.${cfg.tailnetName}.backend or "") == "http://${cfg.listen}"
      && lib.elem "contacts.service" c.mountainous.tailnetNames.${cfg.tailnetName}.after
    ) "contacts must be behind its tailnet HTTPS name"
    ++ hostWant (
      sc.Restart == "on-failure" && sc.KillSignal == "SIGINT"
    ) "contacts must restart on failure and stop gracefully"
  ) enabled
)
