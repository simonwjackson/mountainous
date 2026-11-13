{ inputs, self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    {
      checks.sparkyfitness =
        assert import ../tests/sparkyfitness-contract.nix {
          rakku = self.nixosConfigurations.rakku.config;
          inherit lib;
        };
        pkgs.runCommand "sparkyfitness-contract" { } "touch $out";
    };

  nixos.modules.sparkyfitness =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.sparkyfitness;
      frontendPort = config.mountainous.features.sparkyfitness.frontendPort;
      packages = inputs.sparkyfitness.packages.${pkgs.stdenv.hostPlatform.system};
      persistence = { options, ... }: {
        config = lib.optionalAttrs (options.environment ? persistence) {
          # The tmpfs root cannot allocate stable ownership for persisted state.
          users.users.sparkyfitness.uid = 950;
          users.groups.sparkyfitness.gid = 950;
          environment.persistence."/tundra/permafrost".directories = [
            {
              directory = cfg.stateDir;
              user = cfg.user;
              group = cfg.group;
              mode = "0750";
            }
            {
              directory = config.services.postgresql.dataDir;
              user = "postgres";
              group = "postgres";
              mode = "0700";
            }
          ];
        };
      };
    in
    {
      imports = [
        inputs.sparkyfitness.nixosModules.default
        persistence
      ];

      options.mountainous.features.sparkyfitness.frontendPort = lib.mkOption {
        type = lib.types.port;
        default = 4591;
        description = "Loopback nginx port behind SparkyFitness's tailnet name.";
      };

      config = {
        services.sparkyfitness = {
          enable = lib.mkDefault true;
          # This exact no-test derivation is already built on Unzen.
          backendPackage = lib.mkDefault (
            packages.sparkyfitness-server.overrideAttrs (_: {
              doCheck = false;
            })
          );
          # Two web playback fixes, each dropped once the pin contains it upstream:
          # - preset-equipment: preset workouts lose the exercise equipment, which
          #   hides the per-set plate calculator (CodeWithCJ/SparkyFitness#3567).
          # - progression-warmups: warm-ups count as working sets, so suggested
          #   working weights are built from warm-up loads (CodeWithCJ/SparkyFitness#3569).
          frontendPackage = lib.mkDefault (
            packages.sparkyfitness-frontend.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [
                ./sparkyfitness/preset-equipment.patch
                ./sparkyfitness/progression-warmups.patch
              ];
            })
          );
          frontendUrl = lib.mkDefault "https://sparkyfitness.hummingbird-lake.ts.net";
          nginx.virtualHost = lib.mkDefault "sparkyfitness";
          environmentFile = config.sops.templates."sparkyfitness.env".path;
          extraEnvironment = {
            SPARKY_FITNESS_DISABLE_SIGNUP = "true";
            # Upstream promotes an existing account; it does not create one.
            SPARKY_FITNESS_ADMIN_EMAIL = lib.mkDefault "simon.jackson@gmail.com";
          };
        };
        services.nginx.virtualHosts.${cfg.nginx.virtualHost} = {
          default = false;
          listen = [
            {
              addr = "127.0.0.1";
              port = frontendPort;
            }
          ];
        };
        mountainous.tailnetNames.sparkyfitness = {
          backend = "http://127.0.0.1:${toString frontendPort}";
          after = [
            "nginx.service"
            "sparkyfitness.service"
          ];
          description = "SparkyFitness frontend and API";
        };
        sops.secrets =
          lib.genAttrs
            [
              "sparkyfitness-db-password"
              "sparkyfitness-app-db-password"
              "sparkyfitness-api-encryption-key"
              "sparkyfitness-auth-secret"
              "sparkyfitness-owner-password"
            ]
            (_: {
              sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
              mode = "0400";
            });
        sops.templates."sparkyfitness.env" = {
          # PID 1 reads EnvironmentFile before changing to either the backend's
          # sparkyfitness user or db-init's postgres user. Neither needs file access.
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = [
            "sparkyfitness-db-init.service"
            "sparkyfitness.service"
          ];
          content = ''
            SPARKY_FITNESS_DB_PASSWORD=${config.sops.placeholder.sparkyfitness-db-password}
            SPARKY_FITNESS_APP_DB_PASSWORD=${config.sops.placeholder.sparkyfitness-app-db-password}
            SPARKY_FITNESS_API_ENCRYPTION_KEY=${config.sops.placeholder.sparkyfitness-api-encryption-key}
            BETTER_AUTH_SECRET=${config.sops.placeholder.sparkyfitness-auth-secret}
          '';
        };
        # Follow the memory guard's reclaim-before-kill pattern. Idle is ~640 MiB.
        systemd.services.sparkyfitness.serviceConfig = {
          MemoryHigh = lib.mkDefault "1G";
          MemoryMax = lib.mkDefault "1536M";
        };
      };
    };
}
