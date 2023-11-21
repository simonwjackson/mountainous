{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.cuttlefish;
in {
  options.services.cuttlefish = {
    enable = lib.mkEnableOption "Cuttlefish service";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Cuttlefi.sh package";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Cuttlefish configuration settings.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "Interval for the Cuttlefish service to run.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [cfg.package];

    systemd.services.cuttlefish = {
      description = "Cuttlefish Podcast Downloader";
      wantedBy = ["multi-user.target"];
      path = [cfg.package];

      serviceConfig = {
        ExecStart = let
          jsonConfig = builtins.toJSON cfg.settings;

          yamlConfigFile = pkgs.stdenv.mkDerivation {
            name = "json-to-yaml-converter";
            buildInputs = [pkgs.yq];

            phases = ["installPhase"];

            installPhase = ''
              mkdir -p $out

              echo -e '${jsonConfig}' | ${pkgs.yq}/bin/yq --yaml-output > $out/config.yaml
            '';

            meta = {
              description = "A simple script to convert JSON to YAML using yq";
              license = pkgs.lib.licenses.mit;
            };
          };
        in ''
          ${cfg.package}/bin/cuttlefi.sh --config ${yamlConfigFile}/config.yaml sync
        '';
        Restart = "on-failure";
      };
    };

    systemd.timers.cuttlefishTimer = {
      description = "Timer for Cuttlefish Podcast Downloader";
      wantedBy = ["timers.target"];
      partOf = ["cuttlefish.service"];

      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
      };
    };
  };
}
