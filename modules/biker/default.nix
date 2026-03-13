{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.biker;
in {
  options.services.biker = {
    enable = lib.mkEnableOption "Biker static site";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8484;
      description = "Port for the static file server";
    };

    sourceDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/simonwjackson/code/bikes";
      description = "Path to the bikes source checkout";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "simonwjackson";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.biker = {
      description = "Biker static site server";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = "users";
        Restart = "on-failure";
        RestartSec = 5;
        ExecStart = "${pkgs.static-web-server}/bin/static-web-server --host 127.0.0.1 --port ${toString cfg.port} --root ${cfg.sourceDir}/dist --page-fallback ${cfg.sourceDir}/dist/index.html";
      };
    };
  };
}
