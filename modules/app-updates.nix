{
  config,
  inputs,
  lib,
  ...
}:
let
  hosts = config.nixos.hosts;
  state = "/var/lib/app-updater";
  updateType = lib.types.attrsOf (
    lib.types.submodule {
      options = {
        input = lib.mkOption { type = lib.types.str; };
        schedule = lib.mkOption { type = lib.types.str; };
        hosts = lib.mkOption { type = lib.types.listOf lib.types.str; };
      };
    }
  );
in
{
  nixos.modules.base =
    {
      config,
      lib,
      pkgs,
      options,
      ...
    }:
    let
      apps = config.mountainous.appUpdates;
      updater = pkgs.writeShellApplication {
        name = "app-update";
        runtimeInputs = [
          pkgs.python3
          pkgs.nix
          pkgs.git
          pkgs.openssh
          inputs.deploy-rs.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];
        text = ''exec python3 ${../scripts/app-update.py} "$@"'';
      };
      updateConfig = pkgs.writeText "app-updates.json" (
        builtins.toJSON {
          stateDirectory = state;
          inherit apps;
          builder = {
            knownHosts = toString ../deploy/known_hosts;
            alias = "fuji";
            hostName = "fuji.hummingbird-lake.ts.net";
            privateKey = "${state}/ssh/builder_ed25519";
          };
          hosts = lib.mapAttrs (_: host: host.system) hosts;
        }
      );

    in
    {
      options.mountainous.appUpdates = lib.mkOption {
        type = updateType;
        default = { };
      };
      config = lib.mkMerge [
        {
          mountainous.appUpdates = lib.mkIf (config.networking.hostName == "unzen") {
            pi = {
              input = "pi";
              schedule = "*-*-* 00,06,12,18:00:00 UTC";
              hosts = lib.attrNames hosts;
            };
          };
        }
        (lib.mkIf (apps != { }) {
          assertions = lib.mapAttrsToList (name: app: {
            assertion =
              inputs ? ${app.input}
              && config.mountainous.appProfiles ? ${name}
              && builtins.all (host: hosts ? ${host}) app.hosts;
            message = "appUpdates.${name} requires an existing input, profile and fleet hosts.";
          }) apps;
          environment.systemPackages = [ updater ];
          systemd.services = lib.mapAttrs' (
            name: _:
            lib.nameValuePair "app-update-${name}" {
              description = "Build and deploy only the ${name} application profile";
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              unitConfig.ConditionPathExists = "${state}/enabled";
              environment = {
                HOME = state;
                NIX_REMOTE = "daemon";
                LOCAL_KEY = "${state}/signing-key";
                NIX_SSHOPTS = "-F /dev/null -o BatchMode=yes";
                NIX_CONFIG = ''
                  builders-use-substitutes = true
                  extra-substituters = https://pi.cachix.org https://nix-community.cachix.org
                  extra-trusted-public-keys = pi.cachix.org-1:lGeoGJaZ5ZDabuRzkcD5EBTNnDM4HJ1vqeOxlWk1Flk= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
                '';
              };
              serviceConfig = {
                Type = "oneshot";
                User = "root";
                UMask = "0077";
                StateDirectory = "app-updater";
                StateDirectoryMode = "0700";
                WorkingDirectory = "${state}/repository";
                ExecStart = "${updater}/bin/app-update --config ${updateConfig} --app ${name}";
                TimeoutStartSec = "8h";
                Nice = 10;
                CPUQuota = "400%";
                MemoryMax = "8G";
                TasksMax = 512;
                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ProtectHome = true;
                ReadWritePaths = [
                  state
                  "/nix/var"
                ];
                PrivateTmp = true;
                ProtectKernelTunables = true;
                ProtectKernelModules = true;
                ProtectControlGroups = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                RestrictAddressFamilies = [
                  "AF_INET"
                  "AF_INET6"
                  "AF_UNIX"
                ];
              };
            }
          ) apps;
          systemd.timers = lib.mapAttrs' (
            name: app:
            lib.nameValuePair "app-update-${name}" {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = app.schedule;
                Persistent = true;
                Unit = "app-update-${name}.service";
              };
            }
          ) apps;
        })
        (lib.optionalAttrs (options.environment ? persistence) (
          lib.mkIf (apps != { }) {
            environment.persistence."${
              if config.mountainous ? permafrost then "/permafrost" else "/tundra/permafrost"
            }".directories =
              [
                {
                  directory = state;
                  mode = "0700";
                }
              ];
          }
        ))
      ];
    };
}
