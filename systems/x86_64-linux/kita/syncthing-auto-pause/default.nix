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
    name = "network-dispatcher";
    runtimeInputs = [pkgs.networkmanager syncthingToggleScript];
    text = builtins.readFile ./network-dispatcher.sh;
  };

  myToggleScript = pkgs.writeShellApplication {
    name = "myToggleScript";
    runtimeInputs = [];
    text = ''
      #!/usr/bin/env bash

      export SHARES=(${builtins.concatStringsSep " " cfg.managedShares})

      case "$1" in
      true)
        echo "Metered connection detected. Taking appropriate actions..."
        /snowscape/code/github/simonwjackson/mountainous/main/systems/x86_64-linux/kita/syncthing-auto-pause/syncthing-toggle.sh pause "''${SHARES[@]}"

        ;;
      false)
        echo "No metered connection detected. Proceeding with normal operations..."
        /snowscape/code/github/simonwjackson/mountainous/main/systems/x86_64-linux/kita/syncthing-auto-pause/syncthing-toggle.sh resume "''${SHARES[@]}"

        ;;
      *)
        echo "Error: Unexpected input. Expected 'true' or 'false'."
        exit 1
        ;;
      esac
    '';
  };

  customDispatch = "${networkDispatcherScript}/bin/network-dispatcher --execute ${myToggleScript}/bin/myToggleScript";
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
          source = customDispatch;
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
        ExecStart = customDispatch;
      };
    };
  };
}
