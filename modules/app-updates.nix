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
        persistent = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Catch up missed timer runs after boot.";
        };
        timeout = lib.mkOption {
          type = lib.types.str;
          default = "8h";
          description = "Maximum time for the complete update job.";
        };
        sourceBranch = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Refresh a clean updater checkout to this branch before selecting a candidate.";
        };
        checks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional focused checks, built sequentially on each target architecture.";
        };
        gateFile = lib.mkOption {
          type = lib.types.str;
          default = "${state}/enabled";
          description = "Runtime gate, created only after a successful signed deployment.";
        };
        substituters = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
        trustedPublicKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
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
            knownHosts = "${../deploy/known_hosts}";
            alias = "fuji";
            hostName = "fuji.hummingbird-lake.ts.net";
            privateKey = "${state}/ssh/builder_ed25519";
          };
          nativeBuilders.aarch64-linux = {
            knownHosts = "${../deploy/known_hosts}";
            alias = "yari";
            hostName = "yari.hummingbird-lake.ts.net";
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
            name: app:
            lib.nameValuePair "app-update-${name}" {
              description = "Build and deploy only the ${name} application profile";
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              unitConfig.ConditionPathExists = app.gateFile;
              environment = {
                HOME = state;
                NIX_REMOTE = "daemon";
                LOCAL_KEY = "${state}/signing-key";
                NIX_SSHOPTS = "-F /dev/null -o BatchMode=yes";
                GIT_SSH_COMMAND = "ssh -F /dev/null -i ${state}/ssh/id_ed25519 -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${../deploy/known_hosts}";
                NIX_CONFIG = ''
                  builders-use-substitutes = true
                  extra-substituters = ${lib.concatStringsSep " " app.substituters}
                  extra-trusted-public-keys = ${lib.concatStringsSep " " app.trustedPublicKeys}
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
                TimeoutStartSec = app.timeout;
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
                Persistent = app.persistent;
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
