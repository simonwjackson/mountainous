{ rakku, lib }:
let
  state = "/var/lib/logbook";
  profile = "/nix/var/nix/profiles/per-user/logbook/application";
  core = rakku.systemd.services.logbook.serviceConfig;
  sidecar = rakku.systemd.services.logbook-tsnet.serviceConfig;
  persisted = map (
    p: if builtins.isString p then p else p.directory
  ) rakku.environment.persistence."/tundra/permafrost".directories;
  sudo = builtins.filter (r: builtins.elem "logbook" r.users) rakku.security.sudo.extraRules;
in
assert (import ./rakku-contract.nix rakku).status == "pass";
assert rakku.users.users.logbook.isSystemUser;
assert rakku.users.users.logbook.home == state;
assert !builtins.elem "wheel" rakku.users.users.logbook.extraGroups;
assert !builtins.elem "logbook" rakku.nix.settings.trusted-users;
assert
  rakku.users.users.logbook.openssh.authorizedKeys.keys
  == [ "restrict ${rakku.mountainous.appDeployment.deployPublicKey}" ];
assert builtins.elem rakku.mountainous.appDeployment.signingPublicKey
  rakku.nix.settings.trusted-public-keys;
assert builtins.elem state persisted;
assert core.User == "logbook" && sidecar.User == "logbook";
assert core.ProtectHome && sidecar.ProtectHome;
assert core.ProtectSystem == "strict" && sidecar.ProtectSystem == "strict";
assert core.NoNewPrivileges && sidecar.NoNewPrivileges;
assert core.CapabilityBoundingSet == "" && sidecar.CapabilityBoundingSet == "";
assert core.ReadOnlyPaths == [ "${state}/inbox/gadgetbridge" ];
assert lib.hasPrefix "${profile}/bin/logbook-server --port 3160" core.ExecStart;
assert lib.hasInfix "--gadgetbridge-export ${state}/inbox/gadgetbridge/Gadgetbridge.db"
  core.ExecStart;
assert
  sidecar.ExecStart
  == "${profile}/bin/logbook-tsnet --hostname logbook --state-dir ${state}/state/tsnet --upstream http://127.0.0.1:3160";
assert sidecar.StateDirectory == "logbook/state/tsnet";
assert sidecar.ReadOnlyPaths == [ state ];
assert sidecar.ReadWritePaths == [ "${state}/state/tsnet" ];
assert builtins.length sudo == 1;
assert builtins.length (builtins.head sudo).commands == 2;
assert !(rakku.systemd.paths ? logbook-gadgetbridge);
assert !(rakku.systemd.services ? logbook-gadgetbridge);
assert !builtins.elem 3160 rakku.networking.firewall.allowedTCPPorts;
true
