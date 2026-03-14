{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;

  cfg = config.mountainous.boot.systemd-boot;
in {
  options.mountainous.boot.systemd-boot = {
    enable = mkEnableOption "systemd-boot bootloader";

    timeout = mkOption {
      type = types.int;
      default = 3;
      description = "Boot menu timeout in seconds";
    };

    editor = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the boot loader editor";
    };

    consoleMode = mkOption {
      type = types.str;
      default = "max";
      description = "Console mode for systemd-boot (0, 1, 2, auto, max, keep)";
    };

    configurationLimit = mkOption {
      type = types.nullOr types.int;
      default = 10;
      description = "Maximum number of configurations to keep in boot menu";
    };

    efiVariables = mkOption {
      type = types.bool;
      default = true;
      description = "Whether the bootloader can modify EFI variables";
    };
  };

  config = mkIf cfg.enable {
    boot.loader = {
      efi.canTouchEfiVariables = cfg.efiVariables;

      systemd-boot = {
        enable = true;
        editor = cfg.editor;
        consoleMode = cfg.consoleMode;
        configurationLimit = cfg.configurationLimit;
        # Timeout is handled by boot.loader.timeout
      };

      timeout = cfg.timeout;
    };
  };
}
