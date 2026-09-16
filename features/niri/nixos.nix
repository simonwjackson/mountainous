{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkDefault mkIf;
  cfg = config.mountainous.features.niri;
in {
  config = mkIf cfg.enable {
    # greetd takes one session command, so two compositors cannot both claim it.
    # Fail at evaluation instead of handing the user a login that starts the
    # compositor they did not ask for.
    assertions = [
      {
        assertion = !config.mountainous.features.hyprland.enable;
        message = "mountainous.features.niri and mountainous.features.hyprland both own the greetd session. Enable one compositor per host.";
      }
    ];

    programs.niri.enable = mkDefault true;

    # presets/desktop points greetd at Hyprland with mkDefault. These plain
    # definitions win over that default, so a niri host logs into niri.
    services.greetd.settings = {
      default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
      initial_session.command = "niri-session";
    };
  };
}
