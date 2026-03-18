{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) concatMapStringsSep concatStringsSep mkIf mkMerge;
  cfg = config.mountainous.features.borgbackup;
  home = "/home/${cfg.user}";
  hostname = config.networking.hostName;

  repoNames = builtins.attrNames config.services.borgbackup.jobs;

  borgDefaults = {
    exclude = [
      "*/__pycache__"
      "*/.git"
      "*/shell.nix"
    ];
    encryption = {
      mode = "repokey";
      passCommand = "cat ${cfg.passphraseFile}";
    };
    compression = "auto,zstd";
    startAt = "daily";
    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 6;
    };
    user = cfg.user;
  };
in {
  config = mkIf cfg.enable (mkMerge [
    # ── Borg Jobs ────────────────────────────────────────────────────────
    {
      services.borgbackup.jobs = {
        biometrics =
          borgDefaults
          // {
            paths = ["${home}/biometrics"];
            repo = "${cfg.repoBase}/biometrics";
          };
        fitness =
          borgDefaults
          // {
            paths = ["${home}/fitness"];
            repo = "${cfg.repoBase}/fitness";
          };
        nutrition =
          borgDefaults
          // {
            paths = ["${home}/.local/share/nutrition"];
            repo = "${cfg.repoBase}/nutrition";
          };
        tasks =
          borgDefaults
          // {
            paths = ["${home}/.local/share/tasks"];
            repo = "${cfg.repoBase}/tasks";
          };
        omi =
          borgDefaults
          // {
            paths = ["${home}/omi"];
            repo = "${cfg.repoBase}/omi";
          };
        flakey =
          borgDefaults
          // {
            paths = ["${home}/flakey"];
            repo = "${cfg.repoBase}/flakey";
          };
        openclaw =
          borgDefaults
          // {
            paths = ["${home}/.openclaw"];
            exclude = [
              "*/__pycache__"
              "*/.git"
              "*/shell.nix"
              "*/node_modules"
              "*/browser"
              "*/.cache"
            ];
            repo = "${cfg.repoBase}/openclaw";
          };
        code =
          borgDefaults
          // {
            paths = ["${home}/code"];
            exclude = [
              # Version control
              "*/.git"

              # JS/TS
              "*/node_modules"
              "*/.next"
              "*/.nuxt"
              "*/.output"
              "*/.svelte-kit"
              "*/.parcel-cache"
              "*/.turbo"
              "*/.expo"
              "*/.yarn/cache"
              "*/.yarn/unplugged"
              "*/.pnpm-store"

              # Build output
              "*/dist"
              "*/build"
              "*/out"
              "*/_build"
              "*/result"

              # Python
              "*/__pycache__"
              "*/.venv"
              "*/venv"
              "*/.tox"
              "*.pyc"
              "*/.mypy_cache"
              "*/.ruff_cache"

              # Nix
              "*/.direnv"
              "*/.devenv"

              # Rust/Go
              "*/target"

              # Java/Android
              "*/.gradle"
              "*/.idea"

              # Logs
              "*/.loop-worktrees"
              "*/.loop-logs"
              "*/.forgerie"
              "*/logs/*.log"

              # IDE / editor
              "*/.vs"
              "*/obj/Debug"

              # Temp / ephemeral
              "*/.tmp-home*"
              "*/storybook-static"

              # General
              "*/.cache"
              "*/coverage"
              "*/.terraform"
              "*.o"
              "*.so"
              "*.dylib"
            ];
            repo = "${cfg.repoBase}/code";
          };
      };
    }

    # ── Offsite rsync ──────────────────────────────────────────────────
    (mkIf cfg.offsiteSync.enable {
      systemd.services.borg-offsite-sync = {
        description = "Sync borg repos to offsite targets";
        after = [
          "borgbackup-job-biometrics.service"
          "borgbackup-job-fitness.service"
          "borgbackup-job-nutrition.service"
          "borgbackup-job-tasks.service"
          "borgbackup-job-omi.service"
          "borgbackup-job-code.service"
        ];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
        };
        path = with pkgs; [rsync openssh];
        script = let
          repos = concatStringsSep " " repoNames;
          syncLines = concatMapStringsSep "\n" (target: let
            parts = lib.splitString ":" target;
            host = builtins.head parts;
            basePath = lib.concatStringsSep ":" (builtins.tail parts);
          in ''    rsync -az --delete "${cfg.repoBase}/$repo/" "${host}:${basePath}/${hostname}/$repo/" || true'')
          cfg.offsiteSync.targets;
        in ''
          for repo in ${repos}; do
            if [ -d "${cfg.repoBase}/$repo" ]; then
          ${syncLines}
            fi
          done
        '';
      };

      systemd.timers.borg-offsite-sync = {
        description = "Offsite sync of borg repos";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = cfg.offsiteSync.schedule;
          Persistent = true;
        };
      };
    })

    # ── Cloud rclone sync ──────────────────────────────────────────────
    (mkIf cfg.cloudSync.enable {
      environment.systemPackages = [pkgs.rclone];

      systemd.services.borg-cloud-sync = {
        description = "Sync borg repos to cloud storage";
        after = map (name: "borgbackup-job-${name}.service") repoNames;
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
        };
        path = [pkgs.rclone];
        script = let
          repos = concatStringsSep " " repoNames;
          syncLines = concatMapStringsSep "\n" (remote:
            ''    rclone sync "${cfg.repoBase}/$repo/" "${remote}:backups/${hostname}/$repo/" --transfers 4 --checkers 8'')
          cfg.cloudSync.remotes;
        in ''
          for repo in ${repos}; do
            if [ -d "${cfg.repoBase}/$repo" ]; then
          ${syncLines}
            fi
          done
        '';
      };

      systemd.timers.borg-cloud-sync = {
        description = "Cloud sync of borg repos";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = cfg.cloudSync.schedule;
          Persistent = true;
        };
      };
    })
  ]);
}
