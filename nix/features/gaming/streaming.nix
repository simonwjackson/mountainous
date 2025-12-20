{
  config,
  lib,
  pkgs,
  cfg,
  ...
}: let
  inherit (lib) mkIf optionalAttrs optionalString;

  logPath = "/tmp/sunshine.log";

  # Get monitor from cfg.streaming.monitor
  streamingMonitor = cfg.streaming.monitor;

  # Determine if we need NVENC-specific setup
  useNvenc = cfg.streaming.encoder == "nvenc";
  useKms = cfg.streaming.capture == "kms" || (cfg.streaming.capture == "auto" && useNvenc);

  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  jq = "${pkgs.jq}/bin/jq";

  # Script to disable all monitors except the streaming one (removes from compositor)
  disableOtherMonitorsScript = pkgs.writeShellScript "disable-other-monitors" ''
    # Get all monitor names except the streaming monitor and disable them
    for mon in $(${hyprctl} --instance 0 monitors -j | ${jq} -r '.[].name' | grep -v '^${streamingMonitor}$'); do
      ${hyprctl} --instance 0 keyword monitor "$mon,disable"
    done
  '';

  # Script to restore monitors by reloading hyprland config
  restoreMonitors = pkgs.writeShellScript "restore-monitors" ''
    ${hyprctl} --instance 0 reload
  '';

  # Generate onConnect script for a profile
  makeOnConnect = {
    monitor,
    resolution,
    refresh,
    scaling,
    disableOthers,
  }:
    pkgs.writeShellScript "onConnect-${resolution}-${toString refresh}-${toString scaling}" ''
      ${optionalString disableOthers "${disableOtherMonitorsScript} &&"}
      ${hyprctl} --instance 0 keyword monitor ${monitor},${resolution}@${toString refresh},auto,${toString scaling} &&
      ${hyprctl} --instance 0 dispatch dpms on ${monitor} &&
      ${hyprctl} --instance 0 dispatch workspace 10
    '';

  # Generate onDisconnect script
  makeOnDisconnect = {disableOthers}:
    if disableOthers
    then restoreMonitors
    else "";

  # Convert profile to Sunshine app format
  profileToApp = profile: {
    inherit (profile) name;
    prep-cmd = [
      {
        do = makeOnConnect {
          monitor = streamingMonitor;
          inherit (profile) resolution refresh scaling;
          disableOthers = cfg.streaming.disableOtherMonitors;
        };
        undo = makeOnDisconnect {
          disableOthers = cfg.streaming.disableOtherMonitors;
        };
      }
    ];
  };

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
    // (optionalAttrs (cfg.streaming.adapter != null) {
      adapter_name = cfg.streaming.adapter;
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

    # Note: Sunshine creates its own virtual sinks (sink-sunshine-stereo, etc.)
    # when a client connects, and captures from their monitors automatically.

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
      capSysAdmin = lib.mkDefault useKms;
      openFirewall = true;
      autoStart = true;

      settings =
        {
          log_path = logPath;
          output_name = cfg.streaming.monitorIndex;
          key_rightalt_to_key_win = "enabled";
          # Let Sunshine create and manage its own virtual sinks
          # It will capture from its own sink-sunshine-stereo.monitor
        }
        // encoderSettings;

      # Application configuration from profiles
      applications = {
        apps =
          # Generate apps from profiles
          (map profileToApp cfg.streaming.profiles)
          # Append any user-defined applications
          ++ cfg.streaming.applications;
      };
    };
  };
}
