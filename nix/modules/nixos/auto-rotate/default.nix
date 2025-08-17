{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  cfg = config.mountainous.auto-rotate;
in {
  options.mountainous.auto-rotate = {
    enable = mkEnableOption "Enable automatic screen rotation based on accelerometer";

    accelerometerDevice = mkOption {
      type = types.str;
      default = "/sys/bus/iio/devices/iio:device1";
      description = "Path to accelerometer IIO device";
    };

    hingeDevice = mkOption {
      type = types.str;
      default = "/sys/bus/iio/devices/iio:device4";
      description = "Path to hinge sensor IIO device";
    };

    rotationThreshold = mkOption {
      type = types.int;
      default = 500000;
      description = "Threshold for rotation detection (accelerometer units)";
    };

    debounceTime = mkOption {
      type = types.int;
      default = 2;
      description = "Debounce time in seconds to prevent jittery rotations";
    };

    enableHingeDetection = mkOption {
      type = types.bool;
      default = true;
      description = "Only rotate when device is in tablet mode (hinge angle detection)";
    };

    hingeThreshold = mkOption {
      type = types.int;
      default = 160;
      description = "Hinge angle threshold for tablet mode detection (degrees)";
    };

    hyprlandInstance = mkOption {
      type = types.int;
      default = 0;
      description = "Hyprland instance number";
    };

    pollInterval = mkOption {
      type = types.float;
      default = 0.5;
      description = "Sensor polling interval in seconds";
    };
  };

  config = mkIf cfg.enable {
    # Ensure required packages are available
    environment.systemPackages = with pkgs; [
      auto-rotate
      python3
    ];

    # User-level systemd service for auto-rotation
    systemd.user.services.auto-rotate = {
      description = "Automatic screen rotation service";
      wantedBy = ["default.target"];
      after = ["graphical-session.target"];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10";

        # Environment variables for the service
        Environment = [
          "PATH=${pkgs.hyprland}/bin:${pkgs.jq}/bin:${pkgs.python3}/bin:/run/current-system/sw/bin"
        ];
      };

      script = ''
        # Wait for Hyprland to be ready
        sleep 5

        ${pkgs.auto-rotate}/bin/auto-rotate \
          --accelerometer "${cfg.accelerometerDevice}" \
          --hinge "${cfg.hingeDevice}" \
          --rotation-threshold ${toString cfg.rotationThreshold} \
          --debounce-time ${toString cfg.debounceTime} \
          --hinge-threshold ${toString cfg.hingeThreshold} \
          --hyprland-instance ${toString cfg.hyprlandInstance} \
          --poll-interval ${toString cfg.pollInterval} \
          ${
          if cfg.enableHingeDetection
          then "--enable-hinge"
          else ""
        }
      '';
    };

    # Udev rules for sensor access
    services.udev.extraRules = ''
      # Allow access to IIO devices for rotation detection
      SUBSYSTEM=="iio", GROUP="input", MODE="0664"
      KERNEL=="iio:device*", GROUP="input", MODE="0664"

      # Allow write access to scan_elements for hinge sensor initialization
      SUBSYSTEM=="iio", ATTR{name}=="hinge", RUN+="${pkgs.coreutils}/bin/chgrp -R input /sys%p/scan_elements"
      SUBSYSTEM=="iio", ATTR{name}=="hinge", RUN+="${pkgs.coreutils}/bin/chmod -R g+w /sys%p/scan_elements"

      # Alternative: target specific device paths
      KERNEL=="iio:device4", RUN+="${pkgs.coreutils}/bin/chgrp -R input /sys%p/scan_elements /sys%p/buffer"
      KERNEL=="iio:device4", RUN+="${pkgs.coreutils}/bin/chmod -R g+w /sys%p/scan_elements /sys%p/buffer"
    '';

    # Ensure i2c group exists and user is in it
    users.groups.i2c = {};
    users.users.simonwjackson.extraGroups = ["input" "i2c"];
  };
}
