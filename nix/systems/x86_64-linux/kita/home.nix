{pkgs, ...}: {
  # === MPV tuned for Intel NUC (i3-8109U, Iris Plus 655) ===
  programs.mpv = {
    config = {
      # Hardware decoding (iHD driver for Coffee Lake)
      hwdec = "vaapi";
      vo = "gpu";
      gpu-context = "wayland";

      # Medium quality scaling (GPU can handle lanczos)
      scale = "lanczos";
      cscale = "lanczos";
      dscale = "mitchell";
      correct-downscaling = "yes";

      # Light debanding
      deband = "yes";
      deband-iterations = 2;
      deband-threshold = 35;
      deband-range = 16;

      # Good quality streams (1440p should be fine, 4K may stutter)
      ytdl-format = "bestvideo[height<=1440]+bestaudio/best";

      # Moderate cache
      demuxer-max-bytes = "150M";
      demuxer-max-back-bytes = "75M";
    };

    scripts = with pkgs.mpvScripts; [
      uosc
      thumbfast
      quality-menu
    ];
  };
  mountainous.hyprland = {
    enable = true;
    extraSettings = {
      monitor = [
        ",preferred,auto,auto"
      ];
      exec-once = [
        "systemctl --user start hyprland-session.target"
      ];
    };
  };

  # System-specific settings
  programs.git.settings = {
    init.defaultBranch = "main";
  };

  programs.direnv.enable = true;

  home.packages = with pkgs; [
    neovim
    git
  ];
}
