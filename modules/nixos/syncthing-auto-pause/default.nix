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

  meteredConnectionSyncthingToggle = pkgs.writeShellApplication {
    name = "meteredConnectionSyncthingToggle";
    runtimeInputs = [syncthingToggleScript];
    text = ''
      #!/usr/bin/env bash

      export HOME=/home/simonwjackson
      export SHARES=(${builtins.concatStringsSep " " cfg.managedShares})

      case "$1" in
      true)
        echo "Metered connection detected. Taking appropriate actions..."
        syncthing-toggle pause "''${SHARES[@]}"

        ;;
      false)
        echo "No metered connection detected. Proceeding with normal operations..."
        syncthing-toggle resume "''${SHARES[@]}"

        ;;
      *)
        echo "Error: Unexpected input. Expected 'true' or 'false'."
        exit 1
        ;;
      esac
    '';
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
    services.metered-connection = {
      enable = true;
      scripts = lib.mkAfter [
        "${meteredConnectionSyncthingToggle}/bin/meteredConnectionSyncthingToggle"
      ];
    };
  };
}
