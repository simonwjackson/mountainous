{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.mountainous.auto-blur-image;
in {
  options.mountainous.auto-blur-image = {
    enable = mkEnableOption "Auto blur image service";

    input = mkOption {
      type = types.string;
      description = "Path to input image file to watch for changes";
      example = "/home/user/input.jpg";
    };

    output = mkOption {
      type = types.string;
      description = "Path where blurred image will be saved";
      example = "/home/user/output.jpg";
    };

    amount = mkOption {
      type = types.ints.positive;
      default = 100;
      description = "Amount of blur to apply";
      example = 50;
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.auto-blur-image = {
      Unit = {
        Description = "Auto blur image service";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = toString (pkgs.writeShellScript "auto-blur-watch" ''
          echo "${cfg.input}" | ${pkgs.entr}/bin/entr -n bash -c "
            ${pkgs.mountainous.blur-image}/bin/blur-image \
              --amount ${toString cfg.amount} \
              ${cfg.input} \
              ${cfg.output}
          "
        '');
        Restart = "always";
        RestartSec = 5;
      };

      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };
  };
}
