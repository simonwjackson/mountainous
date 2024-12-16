{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf;

  cfg = config.mountainous.desktops.hyprctl-api;
in {
  options.mountainous.desktops.hyprctl-api = {
    enable = mkEnableOption "Hyprland Control service";
    port = mkOption {
      type = types.port;
      default = 9876;
      description = "Port on which the Hyprland Control server will listen";
    };
    package = mkOption {
      type = types.package;
      default = pkgs.writeShellApplication {
        name = "hyprland-control";
        runtimeInputs = with pkgs; [
          socat
          hyprland
          findutils
          gnugrep
          gawk
          gnused
          jq
        ];
        text = builtins.readFile ./hyprctl-api.sh;
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.hyprland-control = {
      description = "Hyprland Control Service";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      environment = {
        PORT = toString cfg.port;
      };

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/hyprland-control";
        Restart = "on-failure";
      };
    };
  };
}
