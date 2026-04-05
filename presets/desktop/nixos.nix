{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkDefault mkIf;
  cfg = config.mountainous.presets.desktop;
in {
  config = mkIf cfg.enable {
    programs.dconf.enable = mkDefault true;

    mountainous.features.hyprland.enable = mkDefault true;
    mountainous.features.dictation.enable = mkDefault true;
    mountainous.features.matrix-notifications.enable = mkDefault true;
    mountainous.features.evdev-hotkey = {
      enable = mkDefault true;
      bindings.saramonic-dictation = {
        deviceName = mkDefault "Saramonic BTW";
        keyCode = mkDefault 200;
        command = mkDefault ["dictation"];
      };
    };

    xdg.portal = {
      enable = mkDefault true;
      wlr.enable = mkDefault true;
      extraPortals = mkDefault [pkgs.darkman pkgs.xdg-desktop-portal-gtk];
      config.common = {
        default = mkDefault "*";
        "org.freedesktop.impl.portal.Settings" = mkDefault ["darkman"];
      };
    };

    services.greetd = {
      enable = mkDefault true;
      useTextGreeter = mkDefault true;
      settings = {
        default_session = {
          command = mkDefault "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
          user = mkDefault "greeter";
        };
        initial_session = {
          command = mkDefault "Hyprland";
          user = mkDefault "simonwjackson";
        };
      };
    };

    fonts.packages = mkDefault [pkgs.nerd-fonts.symbols-only];
  };
}
