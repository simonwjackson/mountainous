{
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
}
