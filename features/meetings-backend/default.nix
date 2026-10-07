{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) attrByPath mkEnableOption mkIf mkMerge mkOption optional types;
  cfg = config.mountainous.features.meetings-backend;
  tsnetProxyEnabled = attrByPath ["mountainous" "features" "tsnet-proxy" "enable"] false config;
in {
  options.mountainous.features.meetings-backend = {
    enable = mkEnableOption "meeting transcript store (meetings serve)";

    package = mkOption {
      type = types.package;
      default = inputs.meetings.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "inputs.meetings.packages.\${system}.default";
      description = "The meetings package.";
    };

    user = mkOption {
      type = types.str;
      default = "simonwjackson";
      description = ''
        User whose systemd user manager runs the service. The store is in
        that user's $XDG_DATA_HOME/meetings, so the Prose files are readable
        and editable by that user. The user needs lingering.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 8179;
      description = "Loopback TCP port for the HTTP ingest endpoint.";
    };

    proxy = {
      enable = mkEnableOption "expose the meetings endpoint through tsnet-proxy";

      hostname = mkOption {
        type = types.str;
        default = "meetings";
        description = "Tailscale hostname for the meetings endpoint.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = optional cfg.proxy.enable {
        assertion = tsnetProxyEnabled;
        message = "mountainous.features.meetings-backend.proxy requires mountainous.features.tsnet-proxy.enable = true";
      };

      users.users.${cfg.user}.linger = true;

      home-manager.users.${cfg.user}.systemd.user.services.meetings = {
        Unit.Description = "Meeting transcript store";
        Service = {
          ExecStart = "${lib.getExe cfg.package} serve --listen 127.0.0.1:${toString cfg.port}";
          Restart = "on-failure";
          RestartSec = "5s";
          UMask = "0077";
        };
        Install.WantedBy = ["default.target"];
      };
    }

    (mkIf cfg.proxy.enable {
      mountainous.features.tsnet-proxy.services.meetings = {
        host = "127.0.0.1";
        hostname = cfg.proxy.hostname;
        interactiveLogin = true;
        openFirewall = false;
        port = cfg.port;
        protocol = "http";
      };
    })
  ]);
}
