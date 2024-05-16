{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption;
  inherit (lib.types) str;

  cfg = config.mountainous.taskwarrior-sync;
in {
  options.mountainous.taskwarrior-sync = {
    enable = mkEnableOption "Whether to enable the taskwarrior sync service";

    privateKeyFile = mkOption {
      type = str;
      description = "";
    };

    publicCertFile = mkOption {
      type = str;
      description = "";
    };

    caCertFile = mkOption {
      type = str;
      description = "";
    };

    server = mkOption {
      type = str;
      description = "";
    };

    credentials = mkOption {
      type = str;
      description = "";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.taskwarrior = {
      enable = true;
      config = {
        confirmation = false;
        taskd = {
          certificate = cfg.publicCertFile;
          key = cfg.privateKeyFile;
          ca = cfg.caCertFile;
          server = cfg.server;
          credentials = cfg.credentials;
        };
      };
    };

    home.file.".local/share/task/hooks/on-exit-sync.sh" = {
      # TODO: move this to an external file
      text = ''
        #!/bin/sh
        # This hooks script syncs task warrior to the configured task server.
        # The on-exit event is triggered once, after all processing is complete.

        # Make sure hooks are enabled


        # Count the number of tasks modified
        n=0
        while read modified_task
        do
            n=$(($n + 1))
        done

        if (($n > 0)); then
            task sync >> ~/sync_hook.log > /dev/null 2>&1 &
        fi

        exit 0
      '';
      executable = true;
    };

    services.taskwarrior-sync = {
      enable = true;
      frequency = "*:0/5";
    };
  };
}
