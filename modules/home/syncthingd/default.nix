{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.syncthingd;

  service = "${config.home.homeDirectory}/.local/bin/start-syncthing.sh";
in {
  options.services.syncthingd = {
    enable = lib.mkEnableOption "Syncthing";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.syncthing;
      description = "The Syncthing package to use.";
    };

    homePath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/syncthing";
      description = "The path where Syncthing configuration will be stored.";
    };

    logFile = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.homePath}/syncthing.log";
      description = "The path to the Syncthing log file.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    home.file."${service}" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        LOG_FILE="/var/log/http-server.log"

        if ! ${pkgs.procps}/bin/ps aux | ${pkgs.gnugrep}/bin/grep -v grep | ${pkgs.gnugrep}/bin/grep -v $$ | ${pkgs.gnugrep}/bin/grep -q "${service}"; then
          # Ensure log directory exists
          mkdir -p "$(dirname "${cfg.logFile}")"

          ${cfg.package}/bin/syncthing -no-browser -home="${cfg.homePath}" >> "${cfg.logFile}"
        fi
      '';
    };

    programs.bash.initExtra = service;
  };
}
