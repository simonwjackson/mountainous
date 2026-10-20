# Exercise the same host module with the optional export bridge enabled.
{ inputs, lib }:
let
  layer =
    (import ../modules/logbook.nix {
      inherit inputs lib;
      self = null;
      config.mountainous.fleetSync.folders.gadgetbridge.enable = true;
    }).nixos.modules.logbook;
  c =
    (inputs.nixpkgs-rakku.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        layer
        (inputs.impermanence-rakku + "/nixos.nix")
        ({ lib, ... }: {
          options.mountainous.appDeployment = lib.mkOption {
            type = lib.types.attrs;
            default.deployPublicKey = "test-public-key";
          };
          config = {
            system.stateVersion = "24.11";
            users.users.simon = {
              isNormalUser = true;
              home = "/home/simon";
            };
          };
        })
      ];
    }).config;
  bridge = c.systemd.services.logbook-gadgetbridge;
in
assert
  c.systemd.paths.logbook-gadgetbridge.pathConfig.PathChanged
  == "/home/simon/.local/share/fleet-sync/gadgetbridge/Gadgetbridge.db";
assert c.systemd.paths.logbook-gadgetbridge.pathConfig.Unit == "logbook-gadgetbridge.service";
assert bridge.serviceConfig.User == "root";
assert bridge.serviceConfig.Restart == "on-failure";
assert bridge.serviceConfig.ReadOnlyPaths == [ "/home/simon" ];
assert bridge.serviceConfig.ReadWritePaths == [ "/var/lib/logbook/inbox/gadgetbridge" ];
assert lib.hasInfix "logbook-export.py" bridge.serviceConfig.ExecStart;
assert lib.hasSuffix
  " /home/simon/.local/share/fleet-sync/gadgetbridge/Gadgetbridge.db /var/lib/logbook/inbox/gadgetbridge/Gadgetbridge.db"
  bridge.serviceConfig.ExecStart;
assert !(bridge.serviceConfig ? ExecStartPost);
assert c.systemd.services.logbook.serviceConfig.ProtectHome;
true
