{
  config,
  lib,
  pkgs,
  cfg,
  ...
}: let
  inherit (lib) mkIf optionalAttrs;

  logPath = "/tmp/sunshine.log";

  # Get monitor names from cfg.streaming.monitors
  primaryMonitor = cfg.streaming.monitors.primary;
  virtualMonitor = cfg.streaming.monitors.virtual;

  # Determine if we need NVENC-specific setup
  useNvenc = cfg.streaming.encoder == "nvenc";
  useKms = cfg.streaming.capture == "kms" || (cfg.streaming.capture == "auto" && useNvenc);

  # Helper script to get Hyprland signature
  getHyprlandSignature = pkgs.writeShellScript "getHyprlandSignature" ''
    ${pkgs.findutils}/bin/find "$XDG_RUNTIME_DIR/hypr/" -maxdepth 1 -type d |
      ${pkgs.gnugrep}/bin/grep -v "^$XDG_RUNTIME_DIR/hypr/$" |
      ${pkgs.gawk}/bin/awk -F'/' '{print $NF}'
  '';

  # Wait for client disconnect from sunshine logs
  waitForDisconnect = pkgs.writeShellScript "waitForDisconnect" ''
    ${pkgs.coreutils}/bin/tail -n 0 -f "${logPath}" |
      ${pkgs.gnugrep}/bin/grep -q "CLIENT DISCONNECTED" && $1
  '';

  # Script to run when client disconnects - switch back to primary monitor
  onDisconnect = pkgs.writeShellScript "onDisconnect" ''
    export PATH="${pkgs.hyprland}/bin:$PATH"

    HYPRLAND_INSTANCE_SIGNATURE=$(${getHyprlandSignature})
    export HYPRLAND_INSTANCE_SIGNATURE

    hyprctl dispatch dpms on ${primaryMonitor}
    hyprctl dispatch moveworkspacetomonitor 2 ${primaryMonitor} &&
      hyprctl dispatch workspace 2 &&
      hyprctl dispatch dpms off ${virtualMonitor}
  '';

  # Script to run when client connects - switch to virtual monitor
  onConnect = pkgs.writeShellScript "onConnect" ''
    export PATH="${pkgs.hyprland}/bin:$PATH"

    HYPRLAND_INSTANCE_SIGNATURE=$(${getHyprlandSignature})
    export HYPRLAND_INSTANCE_SIGNATURE

    hyprctl dispatch dpms on ${virtualMonitor}
    hyprctl dispatch moveworkspacetomonitor 2 ${virtualMonitor} &&
      hyprctl dispatch workspace 2 &&
      hyprctl dispatch dpms off ${primaryMonitor}
  '';

  # Patch sunshine binary to include GPU library path in RPATH
  # Required because setcap binaries ignore LD_LIBRARY_PATH for security
  # This works for both NVIDIA (libcuda) and AMD/Intel (libva) since they're all in /run/opengl-driver/lib
  sunshineWithGpuLibs =
    pkgs.runCommandLocal "sunshine" {
      nativeBuildInputs = [pkgs.patchelf];
      meta.mainProgram = "sunshine";
    } ''
      mkdir -p $out/bin
      cp ${pkgs.sunshine}/bin/sunshine $out/bin/sunshine
      chmod +w $out/bin/sunshine
      patchelf --add-rpath /run/opengl-driver/lib $out/bin/sunshine
    '';

  # Build encoder settings based on configuration
  encoderSettings =
    (optionalAttrs (cfg.streaming.encoder != "auto") {
      encoder = cfg.streaming.encoder;
    })
    // (optionalAttrs (cfg.streaming.capture != "auto") {
      capture = cfg.streaming.capture;
    })
    // (optionalAttrs (cfg.streaming.nvenc.preset != "default") {
      nvenc_preset = cfg.streaming.nvenc.preset;
    })
    // (optionalAttrs (cfg.streaming.nvenc.rateControl != "auto") {
      nvenc_rc = cfg.streaming.nvenc.rateControl;
    })
    // (optionalAttrs cfg.streaming.nvenc.twoPass {
      nvenc_twopass = "enabled";
    });
in {
  config = mkIf cfg.streaming.enable {
    # Override sunshine package to include GPU library paths in RPATH
    # This is needed when using capSysAdmin (which ignores LD_LIBRARY_PATH)
    services.sunshine.package = mkIf useKms sunshineWithGpuLibs;

    # Create a virtual audio sink for streaming on headless systems
    # This provides audio capture even when no physical audio hardware exists
    services.pipewire.wireplumber.configPackages = [
      (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/50-sunshine-virtual-sink.conf" ''
        monitor.alsa.rules = [
          {
            matches = [ { node.name = "~alsa_output.*" } ]
            actions = {
              update-props = {
                # Low latency for streaming
                api.alsa.period-size = 256
                api.alsa.headroom = 512
              }
            }
          }
        ]
      '')
    ];

    # Create virtual sink at user session start for Sunshine audio capture
    systemd.user.services.sunshine-audio-sink = {
      description = "Virtual audio sink for Sunshine streaming";
      wantedBy = ["pipewire.service"];
      after = ["pipewire.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.pulseaudio}/bin/pactl load-module module-null-sink sink_name=sunshine-sink sink_properties=device.description=Sunshine";
        ExecStop = "${pkgs.pulseaudio}/bin/pactl unload-module module-null-sink";
      };
    };

    # DualSense and other gamepad permissions
    services.udev.extraRules = lib.mkMerge [
      ''
        # Uinput for virtual input devices
        KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
        KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
      ''
      ''
        # Sony DualSense (PS5) controller
        KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0660", TAG+="uaccess"
        # Sony DualSense Edge
        KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0df2", MODE="0660", TAG+="uaccess"
        # Sony DualShock 4
        KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="05c4", MODE="0660", TAG+="uaccess"
        KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="09cc", MODE="0660", TAG+="uaccess"
      ''
    ];

    # Configure Sunshine streaming service
    services.sunshine = {
      enable = true;
      # Enable capSysAdmin for KMS capture (required for direct framebuffer access)
      # Only enable if using KMS capture method. Use mkDefault to allow system overrides.
      capSysAdmin = lib.mkDefault useKms;
      openFirewall = true;
      autoStart = true;

      settings =
        {
          log_path = logPath;
          output_name = 0;
          key_rightalt_to_key_win = "enabled";
          # Use our virtual sink for audio capture
          audio_sink = "sunshine-sink";
        }
        // encoderSettings;

      # Default application configuration with monitor switching
      applications = {
        env = {
          PATH = "$(PATH):$(HOME)/.local/bin";
        };
        apps =
          [
            {
              name = "Gaming";
              prep-cmd = [
                {
                  do = onConnect;
                  undo = "";
                }
              ];
              cmd = "${waitForDisconnect} ${onDisconnect}";
              exclude-global-prep-cmd = "false";
              auto-detach = "false";
              wait-all = "false";
            }
          ]
          # Append any user-defined applications from cfg.streaming.applications
          ++ cfg.streaming.applications;
      };
    };
  };
}
