{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge types;
  cfg = config.mountainous.flexget;

  # Overlay to patch flexget with web UI assets
  flexgetOverlay = final: prev: {
    flexget = prev.flexget.overridePythonAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          # Install web UI assets
          mkdir -p $out/${prev.python3.sitePackages}/flexget/ui/v2/dist
          cp -r ${final.flexget-webui}/* $out/${prev.python3.sitePackages}/flexget/ui/v2/dist/
        '';
    });
  };
in {
  options.mountainous.flexget = {
    enable = mkEnableOption "FlexGet media automation";

    user = mkOption {
      type = types.str;
      default = "flexget";
      description = "User to run FlexGet as";
    };

    group = mkOption {
      type = types.str;
      default = "flexget";
      description = "Group to run FlexGet as";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/flexget";
      description = "Directory for FlexGet database and state";
    };

    interval = mkOption {
      type = types.str;
      default = "15m";
      description = "How often to run FlexGet tasks (systemd time format)";
    };

    config = mkOption {
      type = types.lines;
      default = "";
      description = "FlexGet YAML configuration";
      example = ''
        tasks:
          download-shows:
            rss: https://example.com/rss
            series:
              - Breaking Bad
            download: /downloads/tv/
      '';
    };

    webUI = {
      enable = mkEnableOption "FlexGet web UI";

      port = mkOption {
        type = types.port;
        default = 5050;
        description = "Port for FlexGet web UI";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing the web UI password (use agenix)";
        example = "config.age.secrets.flexget-password.path";
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall port for FlexGet web UI";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Apply overlay to patch flexget with web UI
      nixpkgs.overlays = [flexgetOverlay];

      # Create flexget user/group
      users.users.${cfg.user} = mkIf (cfg.user == "flexget") {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        createHome = true;
        description = "FlexGet daemon user";
      };

      users.groups.${cfg.group} = mkIf (cfg.group == "flexget") {};

      # Use upstream NixOS module
      services.flexget = {
        inherit (cfg) user interval;

        enable = true;
        homeDir = cfg.dataDir;
        systemScheduler = true;
        config =
          cfg.config
          + lib.optionalString cfg.webUI.enable ''

            web_server:
              bind: 0.0.0.0
              port: ${toString cfg.webUI.port}
          '';
      };

      # Firewall for web UI
      networking.firewall.allowedTCPPorts =
        lib.optional (cfg.openFirewall && cfg.webUI.enable) cfg.webUI.port;

      # Impermanence integration - persist FlexGet data
      environment.persistence."${config.mountainous.impermanence.persistPath}" =
        mkIf (config.mountainous.impermanence.enable or false)
        {
          directories = [
            {
              inherit (cfg) user group;
              directory = cfg.dataDir;
              mode = "0700";
            }
          ];
        };
    }

    # Set web UI password from agenix secret
    (mkIf (cfg.webUI.enable && cfg.webUI.passwordFile != null) {
      systemd.services.flexget-set-password = {
        description = "Set FlexGet web UI password";
        wantedBy = ["multi-user.target"];
        before = ["flexget.service"];
        after = ["agenix.service"];
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.group;
          ExecStart = pkgs.writeShellScript "flexget-set-password" ''
            PASSWORD=$(cat ${cfg.webUI.passwordFile})
            ${pkgs.flexget}/bin/flexget -c ${cfg.dataDir}/config.yml web passwd "$PASSWORD"
          '';
        };
      };
    })
  ]);
}
