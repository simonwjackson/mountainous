{
  pkgs,
  lib,
  osConfig,
  ...
}: {
  # ============================================================================
  # HOME-MANAGER CONFIGURATION - kuju (GPD Gaming Handheld)
  # ============================================================================

  # Dictation support (voice-to-text)
  mountainous.dictation.enable = true;

  # ============================================================================
  # HYPRSHADE - Screen shader management
  # ============================================================================
  home.packages = [pkgs.hyprshade];

  # Vibrance shader - OLED-like appearance for IPS panel
  xdg.configFile."hypr/shaders/vibrance.glsl".text = ''
    #version 300 es
    precision highp float;

    in vec2 v_texcoord;
    uniform sampler2D tex;
    out vec4 fragColor;

    void main() {
        vec4 c = texture(tex, v_texcoord);

        // Saturation boost (OLED-like vibrance)
        float saturation = 1.35;
        float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
        c.rgb = mix(vec3(luma), c.rgb, saturation);

        // Contrast boost (deeper blacks, brighter highlights)
        float contrast = 1.12;
        c.rgb = (c.rgb - 0.5) * contrast + 0.5;

        // Gamma correction (punchier midtones)
        float gamma = 0.92;
        c.rgb = pow(max(c.rgb, vec3(0.0)), vec3(gamma));

        fragColor = clamp(c, 0.0, 1.0);
    }
  '';

  # Vibrance MAX shader - OLED on steroids
  xdg.configFile."hypr/shaders/vibrance-max.glsl".text = ''
    #version 300 es
    precision highp float;

    in vec2 v_texcoord;
    uniform sampler2D tex;
    out vec4 fragColor;

    void main() {
        vec4 c = texture(tex, v_texcoord);

        // Saturation boost (maximum practical vibrance)
        float saturation = 1.65;
        float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
        c.rgb = mix(vec3(luma), c.rgb, saturation);

        // Contrast boost (deep blacks, bright highlights)
        float contrast = 1.20;
        c.rgb = (c.rgb - 0.5) * contrast + 0.5;

        // Gamma correction (punchy midtones)
        float gamma = 0.88;
        c.rgb = pow(max(c.rgb, vec3(0.0)), vec3(gamma));

        fragColor = clamp(c, 0.0, 1.0);
    }
  '';

  # Hyprshade config - vibrance-max by default
  xdg.configFile."hypr/hyprshade.toml".text = ''
    [[shades]]
    name = "vibrance-max"
    default = true
  '';

  # Direnv for directory-based environments
  programs.direnv.enable = true;

  # ============================================================================
  # MPV - Ultra optimized for AMD Radeon 890M (RDNA 3.5) @ 120Hz
  # Tuned for 7" H-IPS panel (1080p, 500 nits, 100% sRGB, DC dimming)
  # ============================================================================
  programs.mpv = {
    config = {
      # === GPU Backend (Vulkan + gpu-next for RDNA 3.5) ===
      vo = "gpu-next";
      gpu-api = "vulkan";
      gpu-context = "waylandvk";

      # === Hardware Decoding (VA-API for AMD) ===
      # 890M supports AV1, HEVC, H.264, VP9 hardware decode
      hwdec = "vaapi";
      hwdec-codecs = "all";

      # === High Quality Scaling (890M handles this easily) ===
      scale = "ewa_lanczossharp";
      cscale = "ewa_lanczossharp";
      dscale = "mitchell";
      correct-downscaling = "yes";
      linear-downscaling = "yes";
      sigmoid-upscaling = "yes";

      # === Debanding (removes compression artifacts) ===
      deband = "yes";
      deband-iterations = 4;
      deband-threshold = 35;
      deband-range = 16;
      deband-grain = 5;

      # === HDR→SDR Tone Mapping for IPS panel ===
      hdr-compute-peak = "yes";
      tone-mapping = "bt.2446a";
      target-colorspace-hint = "yes";

      # === IPS Panel Optimization (maximize perceived contrast) ===
      # Target contrast ~1000:1 typical for quality IPS
      target-contrast = 1000;
      # Slight gamma boost helps IPS blacks appear deeper
      gamma = "1.1";
      # Color saturation boost compensates for IPS vs OLED
      saturation = 5;
      # Auto ICC profile for color accuracy
      icc-profile-auto = "yes";
      # sRGB target (matches 100% sRGB panel)
      target-prim = "bt.709";
      target-trc = "srgb";

      # === 120Hz Display Optimization ===
      # Smooth motion interpolation for 24/30fps content on 120Hz
      interpolation = "yes";
      tscale = "oversample";
      video-sync = "display-resample";

      # === Audio ===
      audio-channels = "stereo";
      audio-normalize-downmix = "yes";

      # === Streaming Quality (portable - balance quality/bandwidth) ===
      ytdl-format = "bestvideo[height<=1080]+bestaudio/best";

      # === Cache (good for streaming, reasonable for portable) ===
      demuxer-max-bytes = "200M";
      demuxer-max-back-bytes = "100M";
      cache = "yes";
      cache-secs = 120;

      # === Power Efficiency ===
      # Reduce GPU load when window not visible
      stop-screensaver = "yes";

      # === OSD/UI (sized for 7" display) ===
      osd-font-size = 28;
      osd-bar-h = 2;
      osd-border-size = 2;
    };

    scripts = with pkgs.mpvScripts; [
      uosc # Modern touch-friendly UI
      thumbfast # Fast thumbnails for seeking
      quality-menu # Quality selection for streams
    ];
  };

  # ============================================================================
  # HYPRLAND CONFIG
  # ============================================================================
  mountainous.hyprland.extraSettings = {
    # Display rotation for portrait panel (GPD Win Mini 2025)
    monitor = [
      "eDP-1,1920x1080@120,0x0,1.25,transform,0"
    ];

    # Apply hyprshade on startup (uses schedule from hyprshade.toml)
    exec-once = [
      "hyprshade auto"
      "game-session-monitor"
    ];

    # Disable "not responding" popup (interferes with frozen game session)
    misc = {
      enable_anr_dialog = false;
    };

    # L4/R4 back buttons → workspace switching
    bind = [
      ", F20, workspace, 1"
      ", F21, workspace, 2"
    ];
  };
}
