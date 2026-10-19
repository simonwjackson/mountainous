# One brightness level for the laptop panel and every external monitor.
#
# The brightness keys run `mountainous-brightness up|down`. That sets the
# panel at once and wakes a user daemon, which sends the same level to every
# monitor that answers DDC/CI. The daemon also sends it when it starts and
# whenever Hyprland adds a monitor, because a monitor's own value is never
# trusted: another computer may have changed it. See modules/brightness.py.
{ lib, ... }:
let
  script = ./brightness.py;
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.brightness = pkgs.runCommand "brightness" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        python3 ${../tests/test_brightness.py} ${script}
        touch $out
      '';
    };

  nixos.modules.desktop =
    { pkgs, ... }:
    let
      brightness = pkgs.writeShellApplication {
        name = "mountainous-brightness";
        runtimeInputs = [ pkgs.python3 pkgs.ddcutil ];
        text = ''exec python3 ${script} "$@"'';
      };
    in
    {
      # /dev/i2c-* for DDC/CI. The NixOS module also grants it to the user at
      # the seat; the group covers the daemon outside a seat check.
      hardware.i2c.enable = true;
      users.users.simon.extraGroups = [ "i2c" ];

      environment.systemPackages = [ brightness ];

      systemd.user.services.mountainous-brightness = {
        description = "Keep every monitor on the brightness level";
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${lib.getExe brightness} daemon";
          Restart = "always";
          RestartSec = 2;
          Slice = "session.slice";
        };
      };
    };
}
