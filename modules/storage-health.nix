# Server storage health in the top bar: a placeholder until real alert
# monitoring exists.
#
# Every 5 minutes the bar runs storage-health-status. It sends a read-only
# probe over SSH to each host, as the user's normal login, and lists what it
# finds: failed/unknown probes, expected mounts, sync/scrub age, shared-pool
# pressure, last-batch cache receipts, and bcachefs member health.
# The servers need no change; the probe uses only unprivileged reads.
{
  perSystem =
    { pkgs, ... }:
    {
      checks.storage-health =
        pkgs.runCommand "storage-health"
          {
            nativeBuildInputs = [
              pkgs.python3
              pkgs.bash
              pkgs.gawk
              pkgs.gnused
              pkgs.gnugrep
              pkgs.coreutils
              pkgs.jq
              pkgs.nodejs
            ];
          }
          ''
            python3 ${../tests/test_storage_health.py} \
              ${./storage-health-probe.sh} ${./storage-health-status.sh}
            node ${../tests/storage-health-model.js} ${./quickshell/storage-health.js}
            touch $out
          '';
    };

  nixos.modules.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.storage-health;

      status = pkgs.writeShellApplication {
        name = "storage-health-status";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.openssh
        ];
        text = ''
          exec bash ${./storage-health-status.sh} ${./storage-health-probe.sh} ${lib.escapeShellArgs cfg.hosts}
        '';
      };
    in
    {
      options.mountainous.features.storage-health = {
        enable = lib.mkEnableOption "server storage health in the top bar";

        hosts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          # Zao gave its Towada array to Unzen on 2026-10-22 and has no storage
          # left to check; probing it only reported "no topology".
          default = [ "simon@unzen" ];
          description = "SSH targets (user@host) to probe, in display order.";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ status ];
        systemd.user.services.quickshell.environment.STORAGE_HEALTH_ENABLED = "1";
      };
    };
}
