# Evaluate the real fleet with the optional folder enabled, never build a host.
{ inputs, lib }:
let
  trial =
    extra:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ (inputs.import-tree ../modules) ];
      mountainous.fleetSync = lib.recursiveUpdate {
        folders.gadgetbridge.enable = true;
      } extra;
    };
  incomplete = trial { };
  complete = trial {
    externalDevices.phone = {
      deviceId = lib.mkForce "AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA";
      tailnetName = lib.mkForce "phone.hummingbird-lake.ts.net";
    };
  };
  c = complete.nixosConfigurations.rakku.config;
  bridge = c.systemd.services.logbook-gadgetbridge;
in
assert
  !(builtins.tryEval incomplete.nixosConfigurations.rakku.config.system.build.toplevel.drvPath)
  .success;
assert
  (builtins.tryEval incomplete.nixosConfigurations.tate.config.system.build.toplevel.drvPath).success;
assert (builtins.tryEval c.system.build.toplevel.drvPath).success;
assert
  c.systemd.paths.logbook-gadgetbridge.pathConfig.PathChanged
  == "/home/simon/.local/share/fleet-sync/gadgetbridge/Gadgetbridge.db";
assert c.systemd.paths.logbook-gadgetbridge.pathConfig.Unit == "logbook-gadgetbridge.service";
assert bridge.serviceConfig.User == "root";
assert bridge.serviceConfig.Restart == "on-failure";
assert bridge.serviceConfig.ReadOnlyPaths == [ "/home/simon" ];
assert bridge.serviceConfig.ReadWritePaths == [ "/var/lib/logbook/inbox/gadgetbridge" ];
assert lib.hasInfix "/bin/logbook-export " bridge.serviceConfig.ExecStart;
assert lib.hasSuffix
  " /home/simon/.local/share/fleet-sync/gadgetbridge/Gadgetbridge.db /var/lib/logbook/inbox/gadgetbridge/Gadgetbridge.db"
  bridge.serviceConfig.ExecStart;
assert !(bridge.serviceConfig ? ExecStartPost);
assert c.systemd.services.logbook.serviceConfig.ProtectHome;
assert
  c.services.syncthing.settings.devices.phone.addresses
  == [ "tcp://phone.hummingbird-lake.ts.net:22000" ];
assert
  c.services.syncthing.settings.folders.gadgetbridge.ignorePatterns == [
    "!/Gadgetbridge.db"
    "*"
  ];
true
