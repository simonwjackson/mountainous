{
  pkgs,
  config,
  ...
}: {
  # === MPV tuned for powerful AMD system ===
  programs.mpv = {
    config = {
      # Hardware decoding (VA-API via Mesa for AMD)
      hwdec = "vaapi";
      vo = "gpu-next";
      gpu-api = "vulkan";
      gpu-context = "waylandvk";

      # High quality scaling (GPU can handle it)
      scale = "ewa_lanczossharp";
      cscale = "ewa_lanczossharp";
      dscale = "mitchell";
      correct-downscaling = "yes";
      linear-downscaling = "yes";
      sigmoid-upscaling = "yes";

      # Quality features
      deband = "yes";
      deband-iterations = 4;
      deband-threshold = 35;
      deband-range = 16;
      deband-grain = 5;

      # HDR support
      hdr-compute-peak = "yes";
      tone-mapping = "bt.2446a";

      # Prefer best quality streams
      ytdl-format = "bestvideo+bestaudio/best";

      # Interpolation for smooth playback on 120Hz
      interpolation = "yes";
      tscale = "oversample";
      video-sync = "display-resample";

      # Large cache for 4K content
      demuxer-max-bytes = "500M";
      demuxer-max-back-bytes = "250M";
    };

    scripts = with pkgs.mpvScripts; [
      uosc # Modern UI
      thumbfast # Thumbnails for seeking
      quality-menu
    ];
  };
  # Dropbox remote configuration (uses agenix for token)
  programs.rclone = {
    enable = true;
    remotes.dropbox = {
      config.type = "dropbox";
      secrets.token = config.age.secrets.cloud_dropbox-token.path;
    };
  };

  # Bidirectional sync for knowledge base
  mountainous.rclone-bisync = {
    enable = true;
    folders.knowledge = {
      localPath = "/snowscape/knowledge";
      remote = "dropbox";
      remotePath = "knowledge";
      interval = "*:0/5";
      conflictResolve = "newer";
    };
  };

  mountainous.hyprland = {
    extraSettings = {
      monitor = [
        # Corrected positioning: DP-2 at 0x1350 (logical height = 1800/1.3333)
        # This ensures monitors are perfectly aligned without gaps
        "DP-1,2880x1800@120,0x0,1.3333"
        "DP-2,2880x1800@120,0x1350,1.3333"
        "HDMI-A-2,preferred,auto,auto"
      ];
      workspace = [
        # "2,gapsout:0,monitor:[HDMI-A-2],gapsin:5 "
      ];
      exec-once = [
        "systemctl --user start hyprland-session.target"
      ];
      # general = {
      #   gaps_in = 20;
      #   gaps_out = "20,200";
      # };
    };
  };

  mountainous.taskwarrior.enable = true;
  mountainous.dictation.enable = true;

  # System-specific settings
  programs.git.settings = {
    init.defaultBranch = "main";
  };

  programs.direnv.enable = true;

  home.packages = with pkgs; [
    # Move later
    windsurf
    code-cursor

    neovim
    ex # Example extraction utility package from packages directory
  ];

  # Kanshi configuration for display profile management
  # services.kanshi = {
  #   enable = false;
  #   settings = [
  #     {
  #       profile = {
  #         name = "default";
  #         outputs = [
  #           {
  #             criteria = "HDMI-A-2";
  #             status = "disable";
  #           }
  #           {
  #             # INFO: Using DP as "unique" identifiers since they are identical devices
  #             criteria = "DP-1";
  #             status = "enable";
  #           }
  #           {
  #             criteria = "DP-2";
  #             status = "enable";
  #           }
  #         ];
  #         exec = [
  #           "${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor HDMI-A-2,disabled && ${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor DP-2,2880x1800@120,0x1200,1.5 && ${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor DP-1,2880x1800@120,0x0,1.5 && ${pkgs.hyprland}/bin/hyprctl --instance 0 dispatch workspace 1"
  #         ];
  #       };
  #     }
  #   ];
  # };
}
