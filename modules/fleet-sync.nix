# Repository-owned trust and one allow-listed folder per service.
{ config, lib, ... }:
let
  flake = config;
  inherit (lib) mkOption types;
in
{
  options.mountainous.fleetSync = {
    devices = mkOption {
      type = types.attrsOf types.str;
      default = builtins.fromJSON (builtins.readFile ../deploy/fleet-sync-devices.json);
      description = "Host names and public Syncthing device IDs, enrolled with scripts/fleet-sync-enroll.";
    };
    externalDevices = mkOption {
      default = { };
      description = "Non-NixOS peers. Copy their existing Syncthing identity; never enroll them with fleet-sync-enroll.";
      type = types.attrsOf (
        types.submodule {
          options = {
            deviceId = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Public Syncthing device ID from the external device.";
            };
            tailnetName = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Full MagicDNS name, for example phone.hummingbird-lake.ts.net.";
            };
          };
        }
      );
    };
    folders = mkOption {
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = lib.mkEnableOption "this allow-listed sync folder" // {
              default = true;
            };
            hosts = mkOption { type = types.listOf types.str; };
            files = mkOption {
              type = types.listOf (types.strMatching "[A-Za-z0-9_.-]+");
              description = "Top-level file names to sync. All other files are ignored.";
            };
          };
        }
      );
    };
  };

  config.nixos.modules.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = flake.mountainous.fleetSync;
      host = config.networking.hostName;
      home = config.users.users.simon.home;
      root = "${home}/.local/share/fleet-sync";
      state = "${home}/.local/state/fleet-sync";
      mine = lib.filterAttrs (_: f: (f.enable or true) && lib.elem host f.hosts) cfg.folders;
      members = lib.unique (lib.concatMap (f: f.hosts) (lib.attrValues mine));
      peers = lib.filter (h: h != host) members;
      external = cfg.externalDevices;
      externalMembers = lib.filter (name: external ? ${name}) members;
      validExternal =
        name:
        let
          device = external.${name};
        in
        device.deviceId != null
        && builtins.match "[A-Z2-7]{7}(-[A-Z2-7]{7}){7}" device.deviceId != null
        && device.tailnetName != null
        &&
          builtins.match "[a-z0-9]([a-z0-9-]*[a-z0-9])?\\.hummingbird-lake\\.ts\\.net" device.tailnetName
          != null;
      secret = {
        sopsFile = ../secrets/hosts + "/${host}.yaml";
        owner = "simon";
        mode = "0400";
      };
    in
    lib.mkIf (mine != { }) {
      assertions = [
        {
          assertion = builtins.all (
            h: external ? ${h} || (flake.nixos.hosts ? ${h} && cfg.devices ? ${h})
          ) members;
          message = "fleetSync: each folder member must be an enrolled NixOS host (scripts/fleet-sync-enroll) or a mountainous.fleetSync.externalDevices entry.";
        }
        {
          assertion = builtins.all (h: !(flake.nixos.hosts ? ${h}) && !(cfg.devices ? ${h})) externalMembers;
          message = "fleetSync: externalDevices names must not overlap NixOS hosts or enrolled devices.";
        }
        {
          assertion = builtins.all validExternal externalMembers;
          message = "fleetSync: fill in mountainous.fleetSync.externalDevices.<name>.deviceId (the phone's 8-group Syncthing device ID) and tailnetName (its full <name>.hummingbird-lake.ts.net DNS name). For phone, edit the two null placeholders in modules/logbook.nix before enabling mountainous.fleetSync.folders.gadgetbridge.enable.";
        }
        {
          assertion = builtins.all (f: f.files != [ ]) (lib.attrValues mine);
          message = "fleetSync: a folder needs at least one allowed file.";
        }
      ];
      sops.secrets.syncthing-cert = secret;
      sops.secrets.syncthing-key = secret;
      systemd.tmpfiles.rules = [
        "d ${home}/.local 0755 simon users -"
        "d ${home}/.local/share 0755 simon users -"
        "d ${home}/.local/state 0700 simon users -"
        "d ${root} 0700 simon users -"
        "d ${state} 0700 simon users -"
      ]
      ++ lib.mapAttrsToList (name: _: "d ${root}/${name} 0700 simon users -") mine;
      services.syncthing = {
        enable = lib.mkDefault true;
        user = lib.mkDefault "simon";
        group = lib.mkDefault "users";
        dataDir = lib.mkDefault root;
        configDir = lib.mkDefault state;
        cert = config.sops.secrets.syncthing-cert.path;
        key = config.sops.secrets.syncthing-key.path;
        guiAddress = lib.mkDefault "unix://${state}/gui.sock";
        openDefaultPorts = false;
        overrideDevices = true;
        overrideFolders = true;
        settings = {
          options = {
            listenAddresses = [ "tcp://:22000" ];
            globalAnnounceEnabled = false;
            localAnnounceEnabled = false;
            relaysEnabled = false;
            natEnabled = false;
            urAccepted = -1;
            autoUpgradeIntervalH = 0;
          };
          devices = lib.genAttrs peers (name: {
            # Keep invalid placeholders evaluable so assertions explain the fix.
            id =
              if external ? ${name} then
                (if external.${name}.deviceId == null then "" else external.${name}.deviceId)
              else
                cfg.devices.${name} or "";
            addresses = [
              "tcp://${
                if external ? ${name} then
                  (
                    if external.${name}.tailnetName == null then
                      "unconfigured.invalid"
                    else
                      external.${name}.tailnetName
                  )
                else
                  "${name}.hummingbird-lake.ts.net"
              }:22000"
            ];
            introducer = false;
            autoAcceptFolders = false;
          });
          folders = lib.mapAttrs (name: f: {
            id = name;
            path = "${root}/${name}";
            devices = lib.filter (h: h != host) f.hosts;
            ignorePatterns = map (p: "!/${p}") f.files ++ [ "*" ];
            fsWatcherEnabled = true;
            fsWatcherDelayS = 1;
            rescanIntervalS = 60;
            versioning = {
              type = "simple";
              params.keep = "5";
            };
          }) mine;
        };
      };
      # The upstream module applies settings via REST after startup. Close the
      # first-start discovery/relay window before launching the daemon.
      systemd.services.syncthing.serviceConfig.ExecStartPre = lib.mkAfter [
        (lib.escapeShellArgs [
          "${pkgs.python3}/bin/python3"
          "${./fleet-sync-bootstrap.py}"
          (lib.getExe config.services.syncthing.package)
          config.services.syncthing.configDir
          (pkgs.writeText "fleet-sync-bootstrap.json" (
            builtins.toJSON {
              inherit (config.services.syncthing.settings) options;
            }
          ))
        ])
      ];
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22000 ];
    };
}
