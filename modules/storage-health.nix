# Server storage health in the top bar: a placeholder until real alert
# monitoring exists.
#
# Every 5 minutes the bar runs storage-health-status. It sends a read-only
# probe over SSH to each host, as the user's normal login, and lists what it
# finds: failed units, unmounted array disks, a stale SnapRAID sync, a full
# NVMe cache, and bcachefs members that are not read-write or have I/O errors.
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
            ];
          }
          ''
            python3 ${../tests/test_storage_health.py} \
              ${./storage-health-probe.sh} ${./storage-health-status.sh}
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
          # Zao still runs the unified branch, where the user is simonwjackson.
          default = [
            "simonwjackson@zao"
            "simon@unzen"
          ];
          description = "SSH targets (user@host) to probe, in display order.";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ status ];
        systemd.user.services.quickshell.environment.STORAGE_HEALTH_ENABLED = "1";
      };
    };
}
