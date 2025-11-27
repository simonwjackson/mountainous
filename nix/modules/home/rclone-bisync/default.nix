{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types mapAttrs' nameValuePair concatStringsSep;

  cfg = config.mountainous.rclone-bisync;

  # Generate sync script for a folder pair
  mkSyncScript = name: folderCfg: let
    lockFile = "/tmp/rclone-bisync-${name}.lock";
    logFile = "${config.xdg.stateHome}/rclone-bisync/${name}.log";
  in
    pkgs.writeShellScript "rclone-bisync-${name}" ''
      set -euo pipefail

      mkdir -p "$(dirname "${logFile}")"

      log() {
        echo "[$(date -Iseconds)] $*" | tee -a "${logFile}"
      }

      # Check for lock (prevent overlapping syncs)
      if [ -f "${lockFile}" ]; then
        pid=$(cat "${lockFile}" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
          log "Previous sync still running (PID $pid), skipping"
          exit 0
        else
          log "Stale lock file found, removing"
          rm -f "${lockFile}"
        fi
      fi

      echo $$ > "${lockFile}"
      trap 'rm -f "${lockFile}"' EXIT

      mkdir -p "${folderCfg.localPath}"

      log "Starting bisync: ${folderCfg.localPath} <-> ${folderCfg.remote}:${folderCfg.remotePath}"

      # Check if resync is needed (first run or state corrupted)
      RESYNC_FLAG=""
      STATE_DIR="${config.xdg.cacheHome}/rclone/bisync"
      NEEDS_RESYNC="${config.xdg.stateHome}/rclone-bisync/${name}.needs-resync"
      if [ ! -d "$STATE_DIR" ] || [ -z "$(ls -A "$STATE_DIR" 2>/dev/null)" ] || [ -f "$NEEDS_RESYNC" ]; then
        log "Initial sync or resync requested - performing resync"
        RESYNC_FLAG="--resync"
        rm -f "$NEEDS_RESYNC"
      fi

      if ${pkgs.rclone}/bin/rclone bisync \
        "${folderCfg.localPath}" \
        "${folderCfg.remote}:${folderCfg.remotePath}" \
        $RESYNC_FLAG \
        --conflict-resolve ${folderCfg.conflictResolve} \
        --conflict-loser pathname \
        --conflict-suffix "$(date +%Y%m%d-%H%M%S)" \
        --check-access \
        --resilient \
        --recover \
        --max-lock 5m \
        ${concatStringsSep " " folderCfg.extraArgs} \
        2>&1 | tee -a "${logFile}"; then
        log "Sync completed successfully"
      else
        EXIT_CODE=$?
        log "Sync failed with exit code $EXIT_CODE"
        if [ $EXIT_CODE -eq 2 ]; then
          log "Critical error - marking for resync on next run"
          touch "$NEEDS_RESYNC"
        fi
        exit $EXIT_CODE
      fi
    '';

in {
  options.mountainous.rclone-bisync = {
    enable = mkEnableOption "rclone bidirectional sync";

    folders = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          localPath = mkOption {
            type = types.str;
            description = "Local path to sync";
          };

          remote = mkOption {
            type = types.str;
            default = "dropbox";
            description = "rclone remote name (must be configured in programs.rclone.remotes)";
          };

          remotePath = mkOption {
            type = types.str;
            description = "Remote folder path";
          };

          interval = mkOption {
            type = types.str;
            default = "*:0/5";
            description = "Systemd OnCalendar interval (default: every 5 minutes)";
          };

          conflictResolve = mkOption {
            type = types.enum ["newer" "older" "larger" "smaller" "path1" "path2"];
            default = "newer";
            description = "How to resolve conflicts";
          };

          extraArgs = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Additional arguments to pass to rclone bisync";
          };
        };
      });
      default = {};
      description = "Folders to sync bidirectionally";
    };
  };

  config = mkIf cfg.enable {
    # Systemd services
    systemd.user.services = mapAttrs' (name: folderCfg:
      nameValuePair "rclone-bisync-${name}" {
        Unit = {
          Description = "rclone bisync: ${name}";
          After = ["network-online.target"];
          Wants = ["network-online.target"];
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${mkSyncScript name folderCfg}";
          SuccessExitStatus = "0 1";
        };
      }
    ) cfg.folders;

    # Systemd timers
    systemd.user.timers = mapAttrs' (name: folderCfg:
      nameValuePair "rclone-bisync-${name}" {
        Unit.Description = "rclone bisync timer: ${name}";

        Timer = {
          OnCalendar = folderCfg.interval;
          Persistent = true;
          RandomizedDelaySec = "30s";
        };

        Install.WantedBy = ["timers.target"];
      }
    ) cfg.folders;
  };
}
