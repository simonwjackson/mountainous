{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  vibranceShader = "$HOME/.config/hypr/shaders/vibrance.glsl";

  # Tool paths for keybinds
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  grep = "${pkgs.gnugrep}/bin/grep";
  # Use NixOS Steam package (from programs.steam.enable)
  steam = "${osConfig.programs.steam.package}/bin/steam";

  # Focus window if running, otherwise launch app
  focusOrLaunch = class: cmd: "${hyprctl} clients -j | ${grep} -qi '\"class\": \"${class}\"' && ${hyprctl} dispatch focuswindow 'class:^(${class})$' || ${cmd}";
in {
  # ============================================================================
  # HOME-MANAGER CONFIGURATION - kuju (GPD Gaming Handheld)
  # ============================================================================

  # Dictation support (voice-to-text)
  mountainous.dictation.enable = true;

  # Restore vibrance shader after software dimming ends
  home.sessionVariables.RESTORE_SHADER_CMD = "hyprctl keyword decoration:screen_shader ${vibranceShader}";

  # ============================================================================
  # HANDHELD DAEMON (HHD) CONFIGURATION
  # ============================================================================
  # HHD needs a writable config file (it updates state), so we copy instead of symlink
  # Hot-reloads when file changes - no restart needed
  home.activation.hhdConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
        mkdir -p ~/.config/hhd
        cat > ~/.config/hhd/state.yml << 'HHDEOF'
    hhd:
      settings:
        hhd:
          http:
            localhost_only: true
            enable_token: false
    gpd:
      controllers:
        # Menu button: tap=QAM, double-tap=HHD overlay, hold=Xbox button
        l4r4: combo_menu
        # Select + button combos for Xbox shortcuts
        main_chords: select_only
        # DualSense Edge emulation (gyro, touchpad, adaptive triggers)
        controller_mode: dualsense_edge
        # Motion controls enabled
        imu: true
        imu_hz: 400
        nintendo_mode: false
      wincontrols:
        # L4/R4 back buttons emit F20/F21 keycodes for custom Hyprland binds
        r4l4: hhd
        vibration: medium
    HHDEOF
  '';

  # ============================================================================
  # VIBRANCE SHADER - OLED-like appearance for IPS panel
  # ============================================================================
  xdg.configFile."hypr/shaders/vibrance.glsl".text = ''
    #version 300 es
    precision highp float;

    in vec2 v_texcoord;
    out vec4 fragColor;
    uniform sampler2D tex;

    void main() {
        vec4 c = texture(tex, v_texcoord);

        // Saturation boost (OLED-like vibrance)
        float saturation = 1.15;
        float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
        c.rgb = mix(vec3(luma), c.rgb, saturation);

        // Contrast boost (deeper blacks, brighter highlights)
        float contrast = 1.08;
        c.rgb = (c.rgb - 0.5) * contrast + 0.5;

        // Gamma correction (punchier midtones)
        float gamma = 0.95;
        c.rgb = pow(max(c.rgb, vec3(0.0)), vec3(gamma));

        c.rgb = clamp(c.rgb, 0.0, 1.0);
        fragColor = c;
    }
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
      "eDP-1,1920x1080@120,0x0,1.5,transform,0"
    ];

    # Apply vibrance shader by default (OLED-like appearance)
    decoration.screen_shader = "~/.config/hypr/shaders/vibrance.glsl";

    # HHD button bindings
    # Xbox button: BTN_MODE remapped via evsieve → XF86Launch6
    # L4/R4: HHD's keyboard shortcuts not working, keeping placeholders for future
    bind = [
      # Xbox button (XF86Launch6, remapped from BTN_MODE) - Go to Steam workspace, focus/launch Steam
      ", XF86Launch6, exec, ${hyprctl} dispatch workspace 10 && ${focusOrLaunch "steam" steam}"
      # L4 back button (F20) - placeholder (HHD keyboard not working)
      ", F20, exec, echo 'L4 pressed - customize me'"
      # R4 back button (F21) - placeholder
      ", F21, exec, echo 'R4 pressed - customize me'"
    ];

    # Force Steam and games to workspace 10 (new Hyprland syntax)
    windowrule = [
      # Steam client windows
      "workspace 10 silent, match:class steam"
      "workspace 10 silent, match:class Steam"
      "workspace 10 silent, match:title Steam"
      # Steam games (common patterns)
      "workspace 10, match:class r:^steam_app_"
      "workspace 10, match:class gamescope"
      # Make games fullscreen by default
      "fullscreen on, match:class r:^steam_app_"
      "fullscreen on, match:class gamescope"
    ];
  };
}
