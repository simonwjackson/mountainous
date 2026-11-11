# Registry, deployment graph and host access. No host system closure is selected.
{
  config,
  inputs,
  lib,
  self,
  ...
}:
let
  registry = config.mountainous.appProfiles;
  hosts = config.nixos.hosts;
  state = "/var/lib/app-updater";
in
{
  options.mountainous.appProfiles = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          package = lib.mkOption {
            type = lib.types.unspecified;
            description = "system -> application derivation (with version)";
          };
          hosts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = lib.attrNames hosts;
          };
          activation = lib.mkOption {
            type = lib.types.functionTo lib.types.str;
            default = _: ":";
            description = "system -> activation hook, also run when rolling back.";
          };
          hostModule = lib.mkOption {
            type = lib.types.deferredModule;
            default = { };
          };
        };
      }
    );
  };
  config = {
    nixos.modules.base =
      {
        config,
        lib,
        pkgs,
        options,
        ...
      }:
      let
        access = config.mountainous.appDeployment;
        nativeBuild = pkgs.writeShellScript "app-native-build" ''
          exec ${pkgs.python3}/bin/python3 ${../scripts/app-native-build.py} ${config.nix.package}/bin
        '';
        apps = lib.filterAttrs (_: app: app.enable) config.mountainous.appProfiles;
      in
      {
        imports = lib.mapAttrsToList (_: app: app.hostModule) registry;
        options.mountainous = {
          appProfiles = lib.mkOption {
            default = { };
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, ... }:
                {
                  options = {
                    enable = lib.mkOption {
                      type = lib.types.bool;
                      default = true;
                    };
                    profilePath = lib.mkOption {
                      type = lib.types.str;
                      readOnly = true;
                      default = "/nix/var/nix/profiles/apps/${name}";
                    };
                  };
                }
              )
            );
          };
          appDeployment = {
            sshPort = lib.mkOption {
              type = lib.types.port;
              default = 22;
              description = "OpenSSH deployment port (not Tailscale SSH).";
            };
            enable = lib.mkEnableOption "app deployment access after provisioning public keys";
            deployPublicKey = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            signingPublicKey = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            builderPublicKey = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
          };
        };
        config = lib.mkMerge [
          {
            # Explicit entries compose with host service-app profiles. A whole-map
            # option default disappears as soon as another app is declared.
            mountainous.appProfiles = lib.mapAttrs (_: app: {
              enable = lib.mkDefault (lib.elem config.networking.hostName app.hosts);
            }) registry;
            # Dedicated public halves supplied after Unzen key generation.
            # Private halves remain in /var/lib/app-updater on Unzen.
            mountainous.appDeployment = {
              enable = lib.mkDefault true;
              deployPublicKey = lib.mkDefault "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGhp/8qnbyKvwLrXEdZ5t3M1A6z/AxB4Q8MB/73GvWL/ app-deploy@unzen";
              builderPublicKey = lib.mkDefault "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIY+uNvkpK7llyLu/JEv26MmP13DOLDBXL37N8jXhWCw app-builder@unzen";
              signingPublicKey = lib.mkDefault "app-updater-1:gn1abGFkIEnq2UsjXSenWZjNSv6/m1Wb5/vyLDF1WRo=";
            };
            assertions = [
              {
                assertion =
                  !access.enable
                  || (
                    lib.hasPrefix "ssh-ed25519 " access.deployPublicKey
                    && lib.hasPrefix "app-updater-1:" access.signingPublicKey
                    && lib.hasPrefix "ssh-ed25519 " access.builderPublicKey
                  );
                message = "appDeployment requires dedicated deploy, app-updater-1 signing and Fuji builder public keys; provision them before enabling access.";
              }
            ];
            users.groups.app-deploy = { };
            users.users.app-deploy = {
              isSystemUser = true;
              group = "app-deploy";
              home = "/var/lib/app-deploy";
              createHome = true;
              shell = pkgs.bashInteractive;
              hashedPassword = "*";
              openssh.authorizedKeys.keys = lib.optional access.enable "restrict ${access.deployPublicKey}";
            };
            # Only this directory is writable; neither system nor user profiles are.
            systemd.tmpfiles.rules = [ "d /nix/var/nix/profiles/apps 0755 app-deploy app-deploy -" ];
            environment.extraInit = lib.concatMapStringsSep "\n" (
              app: ''export PATH="${app.profilePath}/bin:$PATH"''
            ) (lib.attrValues apps);
            nix.settings.trusted-public-keys = lib.optional access.enable access.signingPublicKey;
          }
          (lib.mkIf (config.networking.hostName == "fuji" && access.enable) {
            users.users.simon.openssh.authorizedKeys.keys = [
              "restrict,command=\"${config.nix.package}/bin/nix-daemon --stdio\" ${access.builderPublicKey}"
            ];
          })
          (lib.mkIf (config.networking.hostName == "yari" && access.enable) {
            users.users.simon.openssh.authorizedKeys.keys = [
              ''restrict,command="${nativeBuild}" ${access.builderPublicKey}''
            ];
          })
          (lib.optionalAttrs (options.environment ? persistence) {
            environment.persistence."${
              if config.mountainous ? permafrost then "/permafrost" else "/tundra/permafrost"
            }".directories =
              [ "/var/lib/app-deploy" ];
          })
        ];
      };

    flake.deploy.nodes = lib.mapAttrs (name: host: {
      hostname = "${name}.hummingbird-lake.ts.net";
      sshUser = "app-deploy";
      user = "app-deploy";
      remoteBuild = false;
      autoRollback = true;
      magicRollback = true;
      activationTimeout = 300;
      confirmTimeout = 60;
      sshOpts = [
        "-p"
        (toString self.nixosConfigurations.${name}.config.mountainous.appDeployment.sshPort)
        "-F"
        "/dev/null"
        "-i"
        "${state}/ssh/id_ed25519"
        "-o"
        "IdentitiesOnly=yes"
        "-o"
        "BatchMode=yes"
        "-o"
        "StrictHostKeyChecking=yes"
        "-o"
        "HostKeyAlias=${name}"
        "-o"
        "HostKeyAlgorithms=ssh-ed25519"
        "-o"
        "UserKnownHostsFile=${../deploy/known_hosts}"
        "-o"
        "GlobalKnownHostsFile=/dev/null"
        "-o"
        "ConnectTimeout=10"
        "-o"
        "ServerAliveInterval=15"
        "-o"
        "ServerAliveCountMax=4"
      ];
      profiles =
        lib.mapAttrs (app: _: {
          profilePath = "/nix/var/nix/profiles/apps/${app}";
          # deploy-rs owns the atomic profile link and rollback; no secondary profile.
          path = inputs.deploy-rs.lib.${host.system}.activate.custom (registry.${app}.package host.system) (
            registry.${app}.activation host.system
          );
        }) (lib.filterAttrs (_: app: lib.elem name app.hosts) registry)
        // config.mountainous.serviceAppDeployProfiles.${name};
    }) hosts;

    perSystem =
      { pkgs, system, ... }:
      let
        graph = {
          nodes = lib.filterAttrs (name: _: hosts.${name}.system == system) self.deploy.nodes;
        };
        # JSON schema validation must not realize every referenced app profile.
        # Keep deploy-activate's real dependencies; remove context only here.
        schemaCheck =
          graph:
          (inputs.deploy-rs.lib.${system}.deployChecks (
            builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.toJSON graph))
          )).deploy-schema;
      in
      {
        packages =
          (lib.mapAttrs' (name: app: lib.nameValuePair "app-${name}" (app.package system)) registry)
          // {
            app-deployer = inputs.deploy-rs.packages.${system}.default;
          };
        checks =
          (inputs.deploy-rs.lib.${system}.deployChecks graph)
          // {
            deploy-schema = schemaCheck graph;
            # The schema checks strings, not executable contents. This real
            # failing derivation must never become a schema-build dependency.
            deploy-schema-isolated = schemaCheck {
              nodes.fixture = {
                hostname = "fixture.invalid";
                profiles.fixture.path = pkgs.runCommand "schema-must-not-build-app" { } "exit 1";
              };
            };
          }
          // lib.mapAttrs' (
            name: app:
            lib.nameValuePair "app-${name}" (
              pkgs.runCommand "check-app-${name}" { } ''
                test -d ${app.package system}/bin
                ${app.package system}/bin/${name} --version
                touch $out
              ''
            )
          ) registry;
      };
  };
}
