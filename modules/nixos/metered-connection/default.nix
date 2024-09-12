{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption types mkOption mkMerge mkIf;

  cfg = config.services.metered-connection;

  networkDispatcherScript = pkgs.writeShellApplication {
    name = "network-dispatcher";
    runtimeInputs = [pkgs.networkmanager pkgs.gnugrep] ++ cfg.scripts;
    text = builtins.readFile ./network-dispatcher.sh;
  };
in {
  options.services.metered-connection = {
    enable = mkEnableOption "Metered Connection Service";
    scripts = mkOption {
      type = types.listOf types.path;
      description = "List of paths to scripts to run on network events";
      default = [];
    };
    networks = mkOption {
      type = types.listOf types.str;
      description = "List of network names to be passed to the network-dispatcher";
      default = [];
    };
  };

  config = mkIf cfg.enable {
    networking.networkmanager.dispatcherScripts = lib.mkAfter [
      {
        source = pkgs.writeScript "metered-connection-handler" ''
          #!${pkgs.bash}/bin/bash
          interface="$1"
          status="$2"

          logger "NetworkManager event: $interface $status"

          case "$status" in
            connectivity-change)
              ${networkDispatcherScript}/bin/network-dispatcher \
                ${lib.concatStringsSep " \\\n    " (map (exe: "--execute ${exe}") cfg.scripts)} \
                ${lib.concatStringsSep " " cfg.networks}
                ;;
          esac

          exit 0
        '';
        type = "basic";
      }
    ];
  };
}
