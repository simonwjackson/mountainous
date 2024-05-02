{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}: let
  cfg = config.mountainous.gaming.core;
  flatpak = lib.getExe pkgs.flatpak;
in {
  options.mountainous.gaming.core = {
    enable = lib.mkEnableOption "Enable gaming";
    isHost = lib.mkEnableOption "Wether or not device will be used for game streaming";
  };

  config = lib.mkIf cfg.enable {
    # WARN: untested
    programs.gamemode = {
      enable = true;
      enableRenice = true;
      settings = {
        custom = {
          start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
          end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
        };

        general = {
          softrealtime = "on";
          inhibit_screensaver = 1;
          renice = 10;
        };

        # gpu = {
        #   apply_gpu_optimisations = "accept-responsibility";
        #   gpu_device = 0;
        #   amd_performance_level = "high";
        # };
      };
    };

    mountainous.gaming.sunshine.enable = cfg.isHost;
    systemd.user.services.startSteam = lib.mkIf (cfg.isHost) {
      path = [pkgs.flatpak];
      description = "Start Steam Flatpak app";
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      after = ["mountSteamAppsOverlay.service"];
      serviceConfig = {
        ExecStart = "${flatpak} run com.valvesoftware.Steam -forcedesktopscaling=1.5 -silent";
        Restart = "on-failure";
      };
    };
  };
}
