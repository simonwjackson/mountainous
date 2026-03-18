{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.mountainous.features.openclaw-gateway;
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
          setupScript = pkgs.writeShellScript "openclaw-setup" ''
            export HOME=${home}
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
