# Save Myoko's Hyprland windows and relaunch them at the next graphical login.
# This does not save application data or unsaved edits.
{ inputs, ... }:
{
  nixos.modules.myoko-session-restore =
    { config, pkgs, ... }:
    let
      # Pin upstream through flake.lock. modules/myoko-session-restore-patch.py
      # rewrites its CLI calls for Myoko's Lua instance and launchers, and
      # replaces its best-effort sweep with deterministic placement.
      script = pkgs.runCommand "myoko-hypr-session-restore" { } ''
        install -Dm755 ${inputs.hypr-session-restore}/hypr-session-restore $out/libexec/hypr-session-restore
        ${pkgs.python3}/bin/python3 ${./myoko-session-restore-patch.py} $out/libexec/hypr-session-restore
        ${pkgs.python3}/bin/python3 -m py_compile $out/libexec/hypr-session-restore
      '';
      restore = pkgs.writeShellApplication {
        name = "hypr-session-restore";
        runtimeInputs = [ pkgs.python3 config.programs.hyprland.package ];
        text = ''
          exec ${pkgs.python3}/bin/python3 ${script}/libexec/hypr-session-restore "$@"
        '';
      };
    in
    {
      environment.systemPackages = [ restore ];

      # The existing login starts this target only after Hyprland publishes
      # its Wayland environment. Never run restore in the current session just
      # because the NixOS system profile changes.
      systemd.user.services.hypr-session-restore = {
        description = "Restore Myoko windows and keep a private session snapshot";
        wantedBy = [ "hyprland-session.target" ];
        partOf = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStartPre = "${restore}/bin/hypr-session-restore restore";
          ExecStart = "${restore}/bin/hypr-session-restore daemon";
          ExecStop = "${restore}/bin/hypr-session-restore save";
          # Restore waits for slow single-instance apps before placing them.
          TimeoutStartSec = 300;
          Restart = "on-failure";
          RestartSec = 2;
        };
      };
    };
}
