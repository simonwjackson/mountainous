{ config, lib, pkgs, ... }:

let
  cfg = config.services.etabli;
in {
  options.services.etabli = {
    enable = lib.mkEnableOption "Etabli agentic workbench";

    port = lib.mkOption {
      type = lib.types.port;
      default = 7398;
      description = "Port to listen on";
    };

    sourceDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/simonwjackson/code/etabli";
      description = "Path to the etabli source checkout";
    };

    anthropicKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing ANTHROPIC_API_KEY (can be an env file with ANTHROPIC_API_KEY=...)";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "simonwjackson";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.etabli = {
      description = "Etabli Agentic Workbench";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        PORT = toString cfg.port;
        STATIC_DIR = "${cfg.sourceDir}/dist";
        HOME = "/home/${cfg.user}";
        NODE_ENV = "production";
      };

      path = [ pkgs.bun pkgs.nodejs pkgs.git ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = "users";
        WorkingDirectory = cfg.sourceDir;
        Restart = "on-failure";
        RestartSec = 5;
      };

      script = ''
        export ANTHROPIC_API_KEY="$(cat ${cfg.anthropicKeyFile})"
        exec ${pkgs.bun}/bin/bun run src/server/index.ts
      '';
    };
  };
}
