{
  lib,
  pkgs,
  osConfig ? {},
  ...
}: let
  cfg = osConfig.mountainous.features.evdev-hotkey or {};
  enabled = cfg.enable or false;
  bindings = cfg.bindings or {};

  mkService = name: binding: let
    startScript = pkgs.writeShellScript "evdev-hotkey-${name}-start" ''
      exec ${pkgs.evdev-hotkey}/bin/evdev-hotkey \
        --device-name ${lib.escapeShellArg binding.deviceName} \
        --key-code ${toString binding.keyCode} \
        --poll-interval ${toString binding.pollInterval} \
        -- ${lib.escapeShellArgs binding.command}
    '';
  in {
    Unit = {
      Description = "evdev hotkey: ${name}";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${startScript}";
      Restart = "always";
      RestartSec = 5;
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
in {
  config = lib.mkIf enabled {
    systemd.user.services =
      lib.mapAttrs'
      (name: binding:
        lib.nameValuePair "evdev-hotkey-${name}" (mkService name binding))
      bindings;
  };
}
