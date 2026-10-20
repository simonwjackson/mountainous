# Evaluate the shipped module with a non-NixOS peer, without fleet credentials.
{ inputs, lib }:
let
  phoneId = "AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA";
  fleet = {
    nixos.hosts.rakku = { };
    mountainous.fleetSync = {
      devices.rakku = "RAKKU";
      externalDevices.phone = {
        deviceId = phoneId;
        tailnetName = "phone.hummingbird-lake.ts.net";
      };
      folders.gadgetbridge = {
        hosts = [
          "rakku"
          "phone"
        ];
        files = [ "Gadgetbridge.db" ];
      };
    };
  };
  evaluate =
    configuration:
    (inputs.nixpkgs-rakku.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        inputs.sops-nix.nixosModules.sops
        (import ../modules/fleet-sync.nix {
          config = configuration;
          inherit lib;
        }).config.nixos.modules.base
        {
          networking.hostName = "rakku";
          system.stateVersion = "24.11";
          users.users.simon = {
            isNormalUser = true;
            home = "/home/simon";
          };
        }
      ];
    }).config;
  host = evaluate fleet;
  missing = evaluate (
    lib.recursiveUpdate fleet {
      mountainous.fleetSync.externalDevices.phone = {
        deviceId = null;
        tailnetName = null;
      };
    }
  );
  disabled = evaluate (
    lib.recursiveUpdate fleet {
      mountainous.fleetSync.externalDevices.phone = {
        deviceId = null;
        tailnetName = null;
      };
      mountainous.fleetSync.folders.gadgetbridge.enable = false;
    }
  );
  valid = c: builtins.all (a: a.assertion || !(lib.hasPrefix "fleetSync:" a.message)) c.assertions;
  unknown = evaluate (
    lib.recursiveUpdate fleet {
      mountainous.fleetSync.folders.gadgetbridge.hosts = [
        "rakku"
        "unknown"
      ];
    }
  );
  collision = evaluate (
    lib.recursiveUpdate fleet {
      mountainous.fleetSync.devices.phone = phoneId;
    }
  );
  other = evaluate (
    lib.recursiveUpdate fleet {
      mountainous.fleetSync.externalDevices.phone = {
        deviceId = null;
        tailnetName = null;
      };
      mountainous.fleetSync.folders.gadgetbridge.hosts = [
        "another-host"
        "phone"
      ];
    }
  );
  invalid = evaluate (
    lib.recursiveUpdate fleet {
      mountainous.fleetSync.externalDevices.phone = {
        deviceId = "TODO";
        tailnetName = "dynamic";
      };
    }
  );
  settings = host.services.syncthing.settings;
in
assert valid host;
assert !(valid missing);
assert valid disabled;
assert !disabled.services.syncthing.enable;
assert !valid unknown;
assert !valid collision;
assert !valid invalid;
assert valid other && !other.services.syncthing.enable;
assert settings.devices.phone.id == phoneId;
assert settings.devices.phone.addresses == [ "tcp://phone.hummingbird-lake.ts.net:22000" ];
assert !settings.devices.phone.introducer && !settings.devices.phone.autoAcceptFolders;
assert settings.folders.gadgetbridge.devices == [ "phone" ];
assert
  settings.folders.gadgetbridge.ignorePatterns == [
    "!/Gadgetbridge.db"
    "*"
  ];
assert !settings.options.globalAnnounceEnabled && !settings.options.localAnnounceEnabled;
assert !settings.options.relaysEnabled && !settings.options.natEnabled;
{
  inherit settings;
  status = "pass";
}
