{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf optionalString;
  cfg = config.mountainous.features.openclaw-gateway;
  matrixCfg = cfg.matrix;
  home = "/home/${cfg.user}";
in {
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      chromium
      stdenv.cc.cc.lib
      android-tools
      nodejs
    ];

    systemd.services.openclaw-gateway = {
      description = "OpenClaw Gateway";
      after = [
        "network-online.target"
        "tailscale.service"
      ];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      path = with pkgs; [
        nodejs
        git
        curl
        chromium
        coreutils
        bash
        android-tools
        cmake
        gnumake
        gcc
      ];
      environment = {
        HOME = home;
        OPENCLAW_STATE_DIR = "${home}/.openclaw";
        OPENCLAW_CONFIG_PATH = "${home}/.openclaw/openclaw.json";
        OPENCLAW_NIX_MODE = "1";
        LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";
      };
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        TimeoutStartSec = "30min";
        EnvironmentFile = cfg.envFile;
        ExecStartPre = let
          # Build the jq filter for Matrix channel config injection
          matrixJqFilter = optionalString matrixCfg.enable (let
            allowFromJson = builtins.toJSON matrixCfg.allowFrom;
          in ''
            MATRIX_PASSWORD=$(cat ${matrixCfg.passwordFile})

            ${pkgs.jq}/bin/jq \
              --arg homeserver "${matrixCfg.homeserver}" \
              --arg userId "${matrixCfg.userId}" \
              --arg password "$MATRIX_PASSWORD" \
              --argjson allowFrom '${allowFromJson}' \
              '
                .channels.matrix.enabled = true |
                .channels.matrix.homeserver = $homeserver |
                .channels.matrix.userId = $userId |
                .channels.matrix.password = $password |
                .channels.matrix.dm.policy = "${matrixCfg.dmPolicy}" |
                .channels.matrix.dm.allowFrom = $allowFrom |
                .channels.matrix.groupPolicy = "${matrixCfg.groupPolicy}" |
                .plugins.entries.matrix.enabled = true
              ' \
              "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
          '');

          setupScript = pkgs.writeShellScript "openclaw-setup" ''
            export HOME=${home}
            mkdir -p "$HOME/.openclaw"
            cd "$HOME/.openclaw"
            ${pkgs.nodejs}/bin/npm install openclaw@latest

            ${optionalString matrixCfg.enable ''
              # Install the Matrix plugin if not already present
              if [ ! -d "$HOME/.openclaw/extensions/matrix" ] && \
                 [ ! -d "$HOME/.openclaw/node_modules/@openclaw/matrix" ]; then
                ${pkgs.nodejs}/bin/node "$HOME/.openclaw/node_modules/openclaw/dist/index.js" \
                  plugins install @openclaw/matrix || true
              fi
            ''}

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

              ${matrixJqFilter}
            fi
          '';
        in "${setupScript}";
        ExecStart = let
          startScript = pkgs.writeShellScript "openclaw-start" ''
            export HOME=${home}
            exec ${pkgs.nodejs}/bin/node "$HOME/.openclaw/node_modules/openclaw/dist/index.js" gateway --port ${toString cfg.port}
          '';
        in "${startScript}";
        Restart = "always";
        RestartSec = 5;
        KillMode = "process";
      };
    };
  };
}
