{pkgs, ...}: {
  # ============================================================================
  # HOME-MANAGER CONFIGURATION - kuju (GPD Gaming Handheld)
  # ============================================================================

  # Gaming handheld specific packages
  home.packages = with pkgs; [
    hyprshade
  ];

  # Dictation support (voice-to-text)
  mountainous.dictation.enable = true;

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
  # HYPRSHADE - IPS display enhancement shaders
  # ============================================================================
  # Vibrance shader makes IPS colors more vivid (closer to OLED pop)
  # Blue light filter for comfortable night use
  xdg.configFile."hypr/shaders/vibrance.glsl".text = ''
    precision highp float;
    varying vec2 v_texcoord;
    uniform sampler2D tex;

    const float vibrance = 0.7;      // Color boost (0.0-1.0)
    const float contrast = 1.25;     // Contrast multiplier
    const float saturation = 1.5;    // Overall saturation

    void main() {
        vec4 c = texture2D(tex, v_texcoord);

        // Smart vibrance (boosts dull colors more)
        float avg = (c.r + c.g + c.b) / 3.0;
        float mx = max(c.r, max(c.g, c.b));
        float amt = (mx - avg) * (-vibrance * 3.0);
        c.rgb = mix(c.rgb, vec3(mx), amt);

        // Saturation boost
        float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
        c.rgb = mix(vec3(luma), c.rgb, saturation);

        // Contrast (centered at 0.5)
        c.rgb = (c.rgb - 0.5) * contrast + 0.5;

        gl_FragColor = clamp(c, 0.0, 1.0);
    }
  '';

  xdg.configFile."hypr/shaders/blue-light-filter.glsl".text = ''
    precision highp float;
    varying vec2 v_texcoord;
    uniform sampler2D tex;

    // Warm color temperature for night (3500K)
    const float temperature = 3500.0;

    void main() {
        vec4 c = texture2D(tex, v_texcoord);
        float temp = temperature / 100.0;
        float r = temp <= 66.0 ? 1.0 : clamp(1.292936 * pow(temp - 60.0, -0.1332047), 0.0, 1.0);
        float g = temp <= 66.0 ? clamp(0.390082 * log(temp) - 0.631841, 0.0, 1.0) : clamp(1.129891 * pow(temp - 60.0, -0.0755148), 0.0, 1.0);
        float b = temp >= 66.0 ? 1.0 : (temp <= 19.0 ? 0.0 : clamp(0.543207 * log(temp - 10.0) - 1.19625, 0.0, 1.0));
        c.rgb *= vec3(r, g, b);
        gl_FragColor = c;
    }
  '';

  # Hyprshade shaders (manual toggle only via SUPER+F7/F8)
  xdg.configFile."hypr/hyprshade.toml".text = ''
    [[shades]]
    name = "vibrance"
    default = true

    [[shades]]
    name = "blue-light-filter"
  '';

  # ============================================================================
  # HYPRLAND CONFIG
  # ============================================================================
  mountainous.hyprland.extraSettings = {
    # Display rotation for portrait panel (GPD Win Mini 2025)
    monitor = [
      "eDP-1,1920x1080@120,0x0,1.5,transform,0"
    ];

    # Hyprshade keybinds
    bind = [
      "SUPER, F7, exec, hyprshade toggle vibrance"
      "SUPER, F8, exec, hyprshade toggle blue-light-filter"
    ];

    # Enable vibrance shader by default
    exec-once = [
      "hyprshade on vibrance"
    ];
  };
}
