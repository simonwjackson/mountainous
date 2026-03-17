{
  config,
  lib,
  pkgs,
  tsnsrv,
  ...
}: {
  imports = [
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostName = "fuji";
  networking.useDHCP = true;
  time.timeZone = "UTC";

  mountainous.presets.core = {
    enable = true;
    passwordHash = "$6$4gXnXZmsRgERP5JC$0p8F935IKYb3wj0aiaTymqaWS0sJhgyZpu9vO8Q5SIF2hSpRZ7d.hy1JIn7TTbL.zjSScFrrjqq.BI6MZQfjW0";
  };
  mountainous.presets.server.enable = true;

  # Do not bind sshd to a specific Tailscale address at boot. tailscale0 can
  # come up after sshd starts, which leaves the daemon failed after a reboot.
  # The firewall still restricts remote SSH access to trusted Tailscale traffic.

  environment.systemPackages = with pkgs;
    [
      chromium
      stdenv.cc.cc.lib
      android-tools
      nodejs
      rclone
      gogcli
      yq
      (python3.withPackages (ps: [ps.pyyaml]))
    ]
    ++ (with pkgs.lifted-scripts; [
      biometrics-oura-sync
      biometrics-withings-sync
      biometrics-ketomojo-sync
      biometrics-import-saa
      biometrics-withings-auth
      fitness-import
      nutrition-lookup
      nutrition-log-meal
      nutrition-daily-summary
      tasks-query
      omi-pipeline
      omi-cron
      ebay-api
      ebay-publish
    ]);

  nix.settings.secret-key-files = ["/etc/nix/signing-key.priv"];

  # ── Secrets ──────────────────────────────────────────────────────────

  age.secrets.tailscale-authkey = {
    file = ../../secrets/tailscale-authkey.age;
    mode = "0440";
    group = "tsnsrv";
  };

  age.secrets.groq-env = {
    file = ../../secrets/groq-env.age;
    mode = "0440";
    owner = "simonwjackson";
  };

  age.secrets."fastest-vpn" = {
    file = ../../secrets/fastest-vpn.age;
    mode = "0400";
  };

  age.secrets."omi-api-key" = {
    file = ../../secrets/omi-api-key.age;
    owner = "simonwjackson";
    mode = "0400";
  };

  age.secrets."google-oauth-client" = {
    file = ../../secrets/google-oauth-client.age;
    owner = "simonwjackson";
    mode = "0400";
  };

  age.secrets."oura-api-token" = {
    file = ../../secrets/oura-api-token.age;
    owner = "simonwjackson";
    mode = "0400";
  };

  age.secrets."withings-client-id" = {
    file = ../../secrets/withings-client-id.age;
    owner = "simonwjackson";
    mode = "0400";
  };

  age.secrets."withings-client-secret" = {
    file = ../../secrets/withings-client-secret.age;
    owner = "simonwjackson";
    mode = "0400";
  };

  age.secrets."ketomojo-client-id" = {
    file = ../../secrets/ketomojo-client-id.age;
    owner = "simonwjackson";
    mode = "0400";
  };

  age.secrets."ketomojo-client-secret" = {
    file = ../../secrets/ketomojo-client-secret.age;
    owner = "simonwjackson";
    mode = "0400";
  };

  age.secrets."hf-token" = {
    file = ../../secrets/hf-token.age;
    owner = "simonwjackson";
    mode = "0400";
  };

  age.secrets."telegram-bot-token" = {
    file = ../../secrets/telegram-bot-token.age;
    owner = "simonwjackson";
    mode = "0400";
  };

  age.secrets.openclaw-env = {
    file = ../../secrets/openclaw-env.age;
    mode = "0400";
    owner = "simonwjackson";
  };

  age.secrets.ebay-api-env = {
    file = ../../secrets/ebay-api-env.age;
    mode = "0400";
    owner = "simonwjackson";
  };

  age.secrets.ebay-refresh-token = {
    file = ../../secrets/ebay-refresh-token.age;
    mode = "0400";
    owner = "simonwjackson";
  };

  age.secrets.nutrition-api-keys = {
    file = ../../secrets/nutrition-api-keys.age;
    mode = "0400";
    owner = "simonwjackson";
  };

  age.secrets."rclone-conf" = {
    file = ../../secrets/rclone-conf.age;
    owner = "simonwjackson";
    mode = "0400";
    path = "/home/simonwjackson/.config/rclone/rclone.conf";
  };

  age.secrets."gogcli-credentials" = {
    file = ../../secrets/gogcli-credentials.age;
    owner = "simonwjackson";
    mode = "0400";
  };

  age.secrets."gogcli-keyring" = {
    file = ../../secrets/gogcli-keyring.age;
    owner = "simonwjackson";
    mode = "0400";
  };

  age.secrets.borg-passphrase = {
    file = ../../secrets/borg-passphrase.age;
    owner = "simonwjackson";
    mode = "0400";
  };

  # ── Services ─────────────────────────────────────────────────────────

  mountainous.features.openclaw = {
    enable = true;
    user = "simonwjackson";
    hfTokenFile = config.age.secrets."hf-token".path;
  };

  mountainous.features.omi = {
    enable = true;
    schedule = "*:0/15:00";
  };

  mountainous.features.kroger = {
    enable = true;
    clientIdFile = config.age.secrets."kroger-client-id".path;
    clientSecretFile = config.age.secrets."kroger-client-secret".path;
  };

  # ── Tailscale ────────────────────────────────────────────────────────

  users.groups.tsnsrv = {};
  users.users.tsnsrv = {
    isSystemUser = true;
    group = "tsnsrv";
  };

  # tsnsrv proxies (fuji uses tsnsrv, not tsnet-proxy)
  systemd.services.tsnsrv-openclaw = {
    description = "tsnsrv Tailscale proxy for OpenClaw";
    after = [
      "network-online.target"
      "openclaw-gateway.service"
    ];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    environment.HOME = "/var/lib/tsnsrv-openclaw";
    serviceConfig = {
      Type = "simple";
      User = "tsnsrv";
      Group = "tsnsrv";
      StateDirectory = "tsnsrv-openclaw";
      Restart = "on-failure";
      RestartSec = 5;
    };
    script = ''
      export TS_AUTHKEY="$(cat ${config.age.secrets.tailscale-authkey.path})"
      exec ${tsnsrv.packages.aarch64-linux.default}/bin/tsnsrv -name openclaw -stateDir /var/lib/tsnsrv-openclaw http://127.0.0.1:18789
    '';
  };

  # ── VPN Namespace ────────────────────────────────────────────────────

  systemd.services.vpn-ns = {
    description = "VPN Network Namespace";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
    serviceConfig = {
      Type = "notify";
      NotifyAccess = "all";
      ExecStart = "${pkgs.vpn-ns}/bin/vpn-ns --setup";
      ExecStop = "${pkgs.vpn-ns}/bin/vpn-ns --cleanup";
      Restart = "always";
      RestartSec = "10s";
    };
    environment = {
      VPN_NS_CONFIG = config.age.secrets."fastest-vpn".path;
      VPN_NS_LOCAL_NETS = "100.64.0.0/10";
    };
  };

  # ── OpenClaw Gateway ─────────────────────────────────────────────────

  systemd.services.openclaw-gateway = {
    description = "OpenClaw Gateway";
    after = [
      "network-online.target"
      "tailscale.service"
    ];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    path = [
      pkgs.nodejs
      pkgs.git
      pkgs.curl
      pkgs.chromium
      pkgs.coreutils
      pkgs.bash
      pkgs.android-tools
      pkgs.cmake
      pkgs.gnumake
      pkgs.gcc
    ];
    environment = {
      HOME = "/home/simonwjackson";
      OPENCLAW_STATE_DIR = "/home/simonwjackson/.openclaw";
      OPENCLAW_CONFIG_PATH = "/home/simonwjackson/.openclaw/openclaw.json";
      OPENCLAW_NIX_MODE = "1";
      LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
    };
    serviceConfig = {
      Type = "simple";
      User = "simonwjackson";
      Group = "users";
      TimeoutStartSec = "30min";
      EnvironmentFile = config.age.secrets.openclaw-env.path;
      ExecStartPre = let
        setupScript = pkgs.writeShellScript "openclaw-setup" ''
          export HOME=/home/simonwjackson
          mkdir -p "$HOME/.openclaw"
          cd "$HOME/.openclaw"
          ${pkgs.nodejs}/bin/npm install openclaw@latest

          CONFIG="$HOME/.openclaw/openclaw.json"
          if [ -f "$CONFIG" ]; then
            ${pkgs.jq}/bin/jq \
              --arg token "$TELEGRAM_BOT_TOKEN" \
              --arg gwtoken "$OPENCLAW_GATEWAY_TOKEN" \
              --arg bravekey "$BRAVE_SEARCH_API_KEY" \
              '.channels.telegram.botToken = $token |
               .gateway.auth.token = $gwtoken |
               .tools.web.search.apiKey = $bravekey' \
              "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
          fi
        '';
      in "${setupScript}";
      ExecStart = let
        startScript = pkgs.writeShellScript "openclaw-start" ''
          export HOME=/home/simonwjackson
          exec ${pkgs.nodejs}/bin/node "$HOME/.openclaw/node_modules/openclaw/dist/index.js" gateway --port 18789
        '';
      in "${startScript}";
      Restart = "always";
      RestartSec = 5;
      KillMode = "process";
    };
  };

  # ── Borg Backup ──────────────────────────────────────────────────────

  services.borgbackup.jobs = let
    borgDefaults = {
      exclude = [
        "*/__pycache__"
        "*/.git"
        "*/shell.nix"
      ];
      encryption = {
        mode = "repokey";
        passCommand = "cat ${config.age.secrets.borg-passphrase.path}";
      };
      compression = "auto,zstd";
      startAt = "daily";
      prune.keep = {
        daily = 7;
        weekly = 4;
        monthly = 6;
      };
      user = "simonwjackson";
    };
  in {
    biometrics =
      borgDefaults
      // {
        paths = ["/home/simonwjackson/biometrics"];
        repo = "/var/lib/borg/biometrics";
      };
    fitness =
      borgDefaults
      // {
        paths = ["/home/simonwjackson/fitness"];
        repo = "/var/lib/borg/fitness";
      };
    nutrition =
      borgDefaults
      // {
        paths = ["/home/simonwjackson/.local/share/nutrition"];
        repo = "/var/lib/borg/nutrition";
      };
    tasks =
      borgDefaults
      // {
        paths = ["/home/simonwjackson/.local/share/tasks"];
        repo = "/var/lib/borg/tasks";
      };
    omi =
      borgDefaults
      // {
        paths = ["/home/simonwjackson/omi"];
        repo = "/var/lib/borg/omi";
      };
    flakey =
      borgDefaults
      // {
        paths = ["/home/simonwjackson/flakey"];
        repo = "/var/lib/borg/flakey";
      };
    openclaw =
      borgDefaults
      // {
        paths = ["/home/simonwjackson/.openclaw"];
        exclude = [
          "*/__pycache__"
          "*/.git"
          "*/shell.nix"
          "*/node_modules"
          "*/browser"
          "*/.cache"
        ];
        repo = "/var/lib/borg/openclaw";
      };
    code =
      borgDefaults
      // {
        paths = ["/home/simonwjackson/code"];
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
        repo = "/var/lib/borg/code";
      };
  };

  # ── Biometrics Sync Timers ──────────────────────────────────────────

  systemd.services.biometrics-oura-sync = {
    description = "Sync Oura Ring data";
    serviceConfig = {
      Type = "oneshot";
      User = "simonwjackson";
    };
    path = with pkgs; [
      curl
      jq
      coreutils
      bash
      python3
      lifted-scripts.biometrics-oura-sync
    ];
    script = ''
      export HOME=/home/simonwjackson
      biometrics-oura-sync
    '';
  };

  systemd.timers.biometrics-oura-sync = {
    description = "Daily Oura Ring sync";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* *:00,30:00";
      Persistent = true;
    };
  };

  systemd.services.biometrics-withings-sync = {
    description = "Sync Withings scale data";
    serviceConfig = {
      Type = "oneshot";
      User = "simonwjackson";
    };
    path = with pkgs; [
      curl
      jq
      coreutils
      bash
      python3
      lifted-scripts.biometrics-withings-sync
    ];
    script = ''
      export HOME=/home/simonwjackson
      biometrics-withings-sync
    '';
  };

  systemd.timers.biometrics-withings-sync = {
    description = "Daily Withings sync";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 16:00:00";
      Persistent = true;
    };
  };

  systemd.services.biometrics-ketomojo-sync = {
    description = "Sync Keto-Mojo readings";
    serviceConfig = {
      Type = "oneshot";
      User = "simonwjackson";
    };
    path = with pkgs; [
      curl
      jq
      coreutils
      bash
      python3
      lifted-scripts.biometrics-ketomojo-sync
    ];
    script = ''
      export HOME=/home/simonwjackson
      biometrics-ketomojo-sync
    '';
  };

  systemd.timers.biometrics-ketomojo-sync = {
    description = "Daily Keto-Mojo sync";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 10:10:00";
      Persistent = true;
    };
  };

  systemd.services.borg-offsite-sync = {
    description = "Sync borg repos to aka and yari";
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
      User = "simonwjackson";
    };
    path = with pkgs; [
      rsync
      openssh
    ];
    script = ''
      for repo in biometrics fitness nutrition tasks omi flakey openclaw code; do
        if [ -d "/var/lib/borg/$repo" ]; then
          rsync -az --delete "/var/lib/borg/$repo/" "aka:/tundra/merged/iceberg/backups/fuji/$repo/" || true
          rsync -az --delete "/var/lib/borg/$repo/" "yari:/var/lib/borg-mirror/fuji/$repo/" || true
        fi
      done
    '';
  };

  systemd.timers.borg-offsite-sync = {
    description = "Daily offsite sync of borg repos";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
    };
  };

  systemd.services.borg-dropbox-sync = {
    description = "Sync borg repos to Dropbox and Google Drive";
    after = [
      "borgbackup-job-biometrics.service"
      "borgbackup-job-fitness.service"
      "borgbackup-job-nutrition.service"
      "borgbackup-job-tasks.service"
      "borgbackup-job-omi.service"
      "borgbackup-job-flakey.service"
      "borgbackup-job-openclaw.service"
      "borgbackup-job-code.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "simonwjackson";
    };
    path = with pkgs; [rclone];
    script = ''
      for repo in biometrics fitness nutrition tasks omi flakey openclaw code; do
        if [ -d "/var/lib/borg/$repo" ]; then
          rclone sync "/var/lib/borg/$repo/" "dropbox:backups/fuji/$repo/" --transfers 4 --checkers 8
          rclone sync "/var/lib/borg/$repo/" "gdrive:backups/fuji/$repo/" --transfers 4 --checkers 8
        fi
      done
    '';
  };

  systemd.timers.borg-dropbox-sync = {
    description = "Daily Dropbox sync of borg repos";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 04:30:00";
      Persistent = true;
    };
  };

  system.stateVersion = "24.11";
}
