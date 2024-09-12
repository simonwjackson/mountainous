{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption types mkOption mkMerge mkIf;

  cfg = config.services.syncthing-auto-pause;

  syncthingToggleScript = pkgs.writeShellApplication {
    name = "syncthing-toggle";
    runtimeInputs = [pkgs.syncthing pkgs.jq];
    text = builtins.readFile ./syncthing-toggle.sh;
  };

  networkDispatcherScript = pkgs.writeShellApplication {
    name = "syncthing-auto-pause-dispatcher";
    runtimeInputs = [pkgs.networkmanager syncthingToggleScript];
    text = builtins.readFile ./syncthing-auto-pause-dispatcher.sh;
  };
in {
  options.services.syncthing-auto-pause = {
    enable = mkEnableOption "Syncthing auto-pause service";

    managedShares = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["share1" "share2"];
      description = "List of Syncthing share names to manage";
    };
  };

  config = mkIf cfg.enable {
    networking.networkmanager.dispatcherScripts = mkMerge [
      [
        {
          source = "${networkDispatcherScript}/bin/syncthing-auto-pause-dispatcher";
          type = "basic";
        }
      ]
    ];

    systemd.services.syncthing-auto-pause-init = {
      description = "Initialize Syncthing auto-pause on boot";
      after = ["network-online.target" "syncthing.service"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${networkDispatcherScript}/bin/syncthing-auto-pause-dispatcher";
      };
    };
  };
}
