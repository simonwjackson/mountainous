{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.mountainous.features.evdev-hotkey;

  hotkeyType = types.submodule {
    options = {
      deviceName = mkOption {
        type = types.str;
        description = "Substring to match against input device names.";
        example = "Saramonic BTW";
      };

      keyCode = mkOption {
        type = types.int;
        description = "evdev key code to listen for.";
        example = 200;
      };

      command = mkOption {
        type = types.listOf types.str;
        description = "Command (and arguments) to run on each key press.";
        example = ["dictation"];
      };

      pollInterval = mkOption {
        type = types.float;
        default = 2.0;
        description = "Seconds between device discovery retries.";
      };
    };
  };
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.evdev-hotkey = {
    enable = mkEnableOption "generic evdev hotkey daemon";

    bindings = mkOption {
      type = types.attrsOf hotkeyType;
      default = {};
      description = "Named hotkey bindings mapping device buttons to commands.";
      example = {
        saramonic-dictation = {
          deviceName = "Saramonic BTW";
          keyCode = 200;
          command = ["dictation"];
        };
      };
    };
  };
}
