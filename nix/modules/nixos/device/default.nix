{
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.mountainous.device;
in {
  options.mountainous.device = {
    # === ROLE (how you USE it) ===
    role = mkOption {
      type = types.enum ["desktop" "portable" "server" "kiosk"];
      default = "desktop";
      description = "Primary usage role - determines software defaults";
    };

    # === PHYSICAL CAPABILITIES (what it CAN do, not current state) ===
    capabilities = {
      battery = mkOption {
        type = types.bool;
        default = false;
        description = "Has a battery - enables power management";
      };

      touchscreen = mkOption {
        type = types.bool;
        default = false;
        description = "Has touchscreen input capability";
      };

      formFactor = mkOption {
        type = types.enum ["tower" "laptop" "tablet" "handheld" "sbc"];
        default = "tower";
        description = "Physical form - affects thermal/power assumptions";
      };
    };

    # === COMPUTED HELPERS (derived from above) ===
    isPortable = mkOption {
      type = types.bool;
      default = cfg.capabilities.battery && cfg.role != "server";
      readOnly = true;
      description = "Computed: portable device that moves around";
    };
  };

  # No config here - this is purely declarative options
  # Features read from config.mountainous.device.*
}
