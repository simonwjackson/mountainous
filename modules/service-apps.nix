# NixOS owns service resources; deploy-rs changes only the signed app profile.
{
  config,
  inputs,
  lib,
  self,
  ...
}:
let
  hosts = config.nixos.hosts;
  appsFor = host: self.nixosConfigurations.${host}.config.mountainous.serviceApps;
  names = lib.unique (lib.concatMap (host: lib.attrNames (appsFor host)) (lib.attrNames hosts));
  appFor =
    name: (appsFor (lib.findFirst (host: appsFor host ? ${name}) null (lib.attrNames hosts))).${name};
  packageFor =
    name: system:
    let
      app = appFor name;
    in
    if app.package != null then app.package system else inputs.${app.input}.packages.${system}.default;
  updatingNames = lib.filter (name: (appFor name).package == null) names;
  activationFor =
    name: host: system: package:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      app = (appsFor host).${name};
      smoke = pkgs.writeShellScript "${name}-smoke" app.smokeCommand;
    in
    inputs.deploy-rs.lib.${system}.activate.custom package ''
      set -euo pipefail
      control=$(${pkgs.coreutils}/bin/readlink -e /run/current-system/sw/bin/${name}-service-control) || {
        echo '${name}: controller is missing from the running system' >&2
        exit 1
      }
      /run/wrappers/bin/sudo -n "$control" stop
      /run/wrappers/bin/sudo -n "$control" start
      deadline=$((SECONDS + ${toString app.activationTimeout}))
      ready() {
        [[ "$(${pkgs.systemd}/bin/systemctl show ${name}.service -p ActiveState --value)" == active ]] &&
          [[ "$(${pkgs.systemd}/bin/systemctl show ${name}-tsnet.service -p ActiveState --value)" == active ]] && ${smoke}
      }
      incarnations() {
        ${pkgs.systemd}/bin/systemctl show ${name}.service ${name}-tsnet.service \
          -p ActiveState -p MainPID -p InvocationID -p NRestarts
      }
      until ready; do
        if (( SECONDS >= deadline )); then
          echo '${name}: activation readiness timed out' >&2
          exit 1
        fi
        ${pkgs.coreutils}/bin/sleep 1
      done
      # RestartSec is 3s. Observe a longer window, and reject any restart even
      # if it lands between samples and happens to be active at both endpoints.
      initial=$(incarnations)
      for ((settled = 0; settled < 5; settled++)); do
        ${pkgs.coreutils}/bin/sleep 1
        if ! ready || [[ "$(incarnations)" != "$initial" ]]; then
          echo '${name}: activation stability check failed' >&2
          exit 1
        fi
      done
    '';
in
{
  config.nixos.modules.base =
    {
      config,
      lib,
      pkgs,
      options,
      ...
    }:
    let
      apps = config.mountainous.serviceApps;
      serviceType = lib.types.submodule (
        { name, config, ... }:
        {
          options = {
            rollbackCanary = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Allow destructive rollback probes only for isolated, data-free test instances.";
            };
            input = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = if config.package == null then name else null;
              description = "Tracked flake input for an automatically updated service; mutually exclusive with package.";
            };
            package = lib.mkOption {
              type = lib.types.nullOr (lib.types.functionTo lib.types.package);
              default = null;
              description = "system -> derivation for in-repository apps. No appUpdates entry is created.";
            };
            schedule = lib.mkOption {
              type = lib.types.str;
              default = "*-*-* 04:00:00 UTC";
            };
            ytDlpSchedule = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional nightly refresh of mutable yt-dlp, independent of the app input.";
            };
            port = lib.mkOption { type = lib.types.port; };
            server = lib.mkOption {
              type = lib.types.strMatching "[a-zA-Z0-9_-]+";
              default = "${name}-server";
            };
            serverArgs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "--data-dir"
                "/var/lib/${name}/data"
              ];
              description = "Arguments after --host 127.0.0.1 --port PORT. Use absolute runtime paths.";
            };
            tailnet = lib.mkOption {
              type = lib.types.str;
              default = "hummingbird-lake.ts.net";
            };
            sidecar = lib.mkOption {
              type = lib.types.strMatching "[a-zA-Z0-9_-]+";
              default = "${name}-tsnet";
            };
            sidecarArgs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "--name"
                name
                "--expected-fqdn"
                "${name}.${config.tailnet}"
                "--upstream"
                "http://127.0.0.1:${toString config.port}"
                "--state"
                "/var/lib/${name}/state/tsnet"
              ];
              description = "Complete sidecar arguments, including its loopback upstream and persistent state path.";
            };
            environment = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
            };
            readOnlyBinds = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Runtime source:destination file binds for applications with fixed credential paths.";
            };
            secrets = lib.mkOption {
              default = { };
              description = "SOPS secret names mapped to paths relative to the service home.";
              type = lib.types.attrsOf lib.types.str;
            };
            smokeCommand = lib.mkOption {
              type = lib.types.lines;
              default = "true";
              description = "Non-root on-host readiness check. Must return promptly; never embed credentials.";
            };
            checkCommand = lib.mkOption {
              type = lib.types.lines;
              default = "true";
              description = "Sandboxed build smoke check; APP_PACKAGE points to the candidate. No network or secrets.";
            };
            activationTimeout = lib.mkOption {
              type = lib.types.ints.between 5 240;
              default = 60;
            };
          };
        }
      );
      state = name: "/var/lib/${name}";
      profile = name: "/nix/var/nix/profiles/apps/${name}";
      controller =
        name:
        pkgs.writeShellApplication {
          name = "${name}-service-control";
          runtimeInputs = [ pkgs.systemd ];
          text = ''
            if [[ $# != 1 ]]; then exit 2; fi
            case "$1" in
              stop) systemctl stop ${name}-tsnet.service ${name}.service ;;
              start)
                systemctl reset-failed ${name}.service ${name}-tsnet.service
                systemctl start ${name}.service ${name}-tsnet.service
                ;;
              *) echo 'Expected start or stop' >&2; exit 2 ;;
            esac
          '';
        };
      resources = lib.mapAttrsToList (
        name: app:
        let
          home = state name;
          common = {
            User = name;
            Group = name;
            WorkingDirectory = home;
            UMask = "0077";
            Restart = "on-failure";
            RestartSec = 3;
            TimeoutStopSec = 30;
            StateDirectory = name;
            StateDirectoryMode = "0700";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [ home ];
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            CapabilityBoundingSet = "";
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
              "AF_NETLINK"
            ];
          };
          unit = binary: {
            environment = {
              HOME = home;
            }
            // app.environment;
            unitConfig.ConditionPathExists = "${profile name}/bin/${binary}";
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
          };
        in
        {
          assertions = [
            {
              assertion = builtins.match "[a-z][a-z0-9-]{0,30}" name != null;
              message = "serviceApps names must be safe system account and unit names.";
            }
            {
              assertion = (app.input != null) != (app.package != null);
              message = "serviceApps.${name}: select exactly one of input or package.";
            }
            {
              assertion = app.input == null || inputs ? ${app.input};
              message = "serviceApps.${name}: selected input does not exist.";
            }
            {
              assertion =
                !(lib.any (
                  arg:
                  arg == "--host" || lib.hasPrefix "--host=" arg || arg == "--port" || lib.hasPrefix "--port=" arg
                ) app.serverArgs);
              message = "serviceApps.${name}: serverArgs cannot override the loopback host or declared port.";
            }
            {
              assertion = lib.all (
                path: !(lib.hasPrefix "/" path) && !(builtins.elem ".." (lib.splitString "/" path))
              ) (lib.attrValues app.secrets);
              message = "serviceApps secret destinations must stay inside the service home.";
            }
          ];
          users.groups.${name} = { };
          users.users.${name} = {
            isSystemUser = true;
            group = name;
            home = home;
            createHome = true;
            homeMode = "0700";
          };
          environment.systemPackages = [ (controller name) ];
          security.sudo.extraRules = [
            {
              users = [ "app-deploy" ];
              runAs = "root";
              commands =
                map
                  (action: {
                    command = "${controller name}/bin/${name}-service-control ${action}";
                    options = [ "NOPASSWD" ];
                  })
                  [
                    "start"
                    "stop"
                  ];
            }
          ];
          systemd.tmpfiles.rules = [
            "d ${home} 0700 ${name} ${name} -"
            "d ${home}/data 0700 ${name} ${name} -"
            "d ${home}/state 0700 ${name} ${name} -"
            "d ${home}/state/tsnet 0700 ${name} ${name} -"
          ]
          ++ map (directory: "d ${home}/${directory} 0700 ${name} ${name} -") (
            lib.unique (map builtins.dirOf (lib.attrValues app.secrets))
          );
          sops.secrets = lib.mapAttrs (_: path: {
            sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
            owner = name;
            group = name;
            mode = "0400";
            restartUnits = [
              "${name}.service"
              "${name}-tsnet.service"
            ];
          }) app.secrets;
          systemd.services.${name} = unit app.server // {
            description = "${name} loopback service app";
            serviceConfig = common // {
              ExecStartPre = lib.mapAttrsToList (
                secret: path:
                "${pkgs.coreutils}/bin/install -m0600 ${config.sops.secrets.${secret}.path} ${home}/${path}"
              ) app.secrets;
              BindReadOnlyPaths = app.readOnlyBinds;
              ExecStart = lib.escapeShellArgs (
                [
                  "${profile name}/bin/${app.server}"
                  "--host"
                  "127.0.0.1"
                  "--port"
                  (toString app.port)
                ]
                ++ app.serverArgs
              );
            };
          };
          systemd.timers = lib.optionalAttrs (app.ytDlpSchedule != null) {
            "${name}-ytdlp-update" = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = app.ytDlpSchedule;
                RandomizedDelaySec = "45min";
                Persistent = true;
              };
            };
          };
          systemd.services."${name}-ytdlp-update" = lib.mkIf (app.ytDlpSchedule != null) {
            description = "Refresh ${name}'s mutable yt-dlp nightly";
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            environment = {
              HOME = home;
            }
            // app.environment;
            unitConfig.ConditionPathExists = "${profile name}/bin/${name}-ytdlp-update";
            serviceConfig = common // {
              Type = "oneshot";
              Restart = "no";
              ExecStart = "${profile name}/bin/${name}-ytdlp-update";
              TimeoutStartSec = "15min";
            };
          };
          systemd.services."${name}-tsnet" = unit app.sidecar // {
            description = "${name} dedicated tailnet node";
            wants = [
              "network-online.target"
              "${name}.service"
            ];
            after = [
              "network-online.target"
              "${name}.service"
            ];
            serviceConfig = common // {
              ExecStart = lib.escapeShellArgs ([ "${profile name}/bin/${app.sidecar}" ] ++ app.sidecarArgs);
              StateDirectory = "${name}/state/tsnet";
              ReadOnlyPaths = [ home ];
              ReadWritePaths = [ "${home}/state/tsnet" ];
            };
          };
        }
      ) apps;
    in
    {
      options.mountainous.serviceApps = lib.mkOption {
        type = lib.types.attrsOf serviceType;
        default = { };
      };
      config = lib.mkMerge [
        {
          mountainous.appProfiles = lib.genAttrs names (_: {
            enable = false;
          });
          mountainous.appUpdates = lib.mkIf (config.networking.hostName == "unzen") (
            lib.genAttrs updatingNames (name: {
              inherit (appFor name) input schedule;
              gateFile = "/var/lib/app-updater/enabled-${name}";
              hosts = lib.filter (host: appsFor host ? ${name}) (lib.attrNames hosts);
            })
          );
          assertions =
            lib.concatMap (r: r.assertions) resources
            ++ map (name: {
              assertion = lib.all (
                host:
                let
                  app = (appsFor host).${name};
                  canonical = appFor name;
                in
                app.input == canonical.input
                && (app.package == null) == (canonical.package == null)
                && (
                  app.package == null
                  || toString (app.package hosts.${host}.system) == toString (canonical.package hosts.${host}.system)
                )
                && app.schedule == canonical.schedule
              ) (lib.filter (host: appsFor host ? ${name}) (lib.attrNames hosts));
              message = "serviceApps.${name} package source and schedule must agree between hosts.";
            }) names;
          users.users = lib.mkMerge (map (r: r.users.users) resources);
          users.groups = lib.mkMerge (map (r: r.users.groups) resources);
          environment.systemPackages = lib.concatMap (r: r.environment.systemPackages) resources;
          security.sudo.extraRules = lib.concatMap (r: r.security.sudo.extraRules) resources;
          sops.secrets = lib.mkMerge (map (r: r.sops.secrets) resources);
          systemd.services = lib.mkMerge (map (r: r.systemd.services) resources);
          systemd.timers = lib.mkMerge (map (r: r.systemd.timers) resources);
          systemd.tmpfiles.rules = lib.concatMap (r: r.systemd.tmpfiles.rules) resources;
        }
        (lib.optionalAttrs (options.environment ? persistence) {
          environment.persistence."${
            if config.mountainous ? permafrost then "/permafrost" else "/tundra/permafrost"
          }".directories =
            lib.mapAttrsToList (name: _: {
              directory = state name;
              user = name;
              group = name;
              mode = "0700";
            }) apps;
        })
      ];
    };

  # Multiple modules export helpers (including memoryGuardModule); make the
  # namespace composable rather than flake-parts' default unique raw output.
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
  };

  options.mountainous.serviceAppDeployProfiles = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    readOnly = true;
    description = "Derived service app deployment profiles, indexed by host.";
  };
  config.mountainous.serviceAppDeployProfiles = lib.mapAttrs (
    host: definition:
    lib.mapAttrs (name: app: {
      profilePath = "/nix/var/nix/profiles/apps/${name}";
      path = activationFor name host definition.system (packageFor name definition.system);
      activationTimeout = app.activationTimeout + 30;
    }) (appsFor host)
  ) hosts;

  # Data-free canary deployment overlay. It reuses the real activation contract
  # without adding a flake input or making test packages eligible for updates.
  config.flake.lib.serviceAppCanaryDeployment =
    {
      host,
      name,
      system,
      fixture,
    }:
    let
      app = (appsFor host).${name};
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      candidate = import fixture {
        inherit pkgs;
        healthy = app.package system;
      };
      node = self.deploy.nodes.${host};
    in
    assert app.rollbackCanary && app.package != null;
    self.deploy
    // {
      nodes = {
        ${host} = node // {
          profiles = {
            ${name} = node.profiles.${name} // {
              path = activationFor name host system candidate;
            };
          };
        };
      };
    };

  config.perSystem =
    { pkgs, system, ... }:
    let
      tools = import ../lib/service-app-tools.nix { inherit pkgs lib; };
    in
    {
      packages =
        (lib.genAttrs (map (name: "app-${name}") names) (
          key: packageFor (lib.removePrefix "app-" key) system
        ))
        // {
          service-app-tools = tools;
        };
      checks = {
        service-app-tools =
          pkgs.runCommand "service-app-tools-contract"
            {
              nativeBuildInputs = [
                pkgs.python3
                pkgs.git
              ];
              SERVICE_APP_SCRIPTS = "${tools}/libexec/service-apps";
            }
            ''
              python3 ${../tests/test_service_apps.py}
              touch "$out"
            '';
        service-apps =
          assert builtins.isFunction self.lib.serviceAppCanaryDeployment;
          assert builtins.isFunction self.lib.memoryGuardModule;
          assert import ../tests/service-apps.nix {
            rakku = self.nixosConfigurations.rakku.config;
            unzen = self.nixosConfigurations.unzen.config;
            inherit (self) deploy;
            inherit lib;
          };
          pkgs.runCommand "service-apps-contract" { } ''
            ${lib.optionalString (system == "x86_64-linux") ''
              test -x ${self.nixosConfigurations.rakku.config.system.path}/bin/groceries-service-control
            ''}
            touch "$out"
          '';
      }
      // lib.genAttrs (map (name: "app-${name}") names) (
        key:
        let
          name = lib.removePrefix "app-" key;
          app = appFor name;
        in
        pkgs.runCommand "check-${key}"
          {
            APP_PACKAGE = packageFor name system;
            nativeBuildInputs = [
              pkgs.curl
              pkgs.python3
            ];
          }
          ''
            test -x "$APP_PACKAGE/bin/${app.server}"
            test -x "$APP_PACKAGE/bin/${app.sidecar}"
            ${app.checkCommand}
            touch "$out"
          ''
      );
    };
}
