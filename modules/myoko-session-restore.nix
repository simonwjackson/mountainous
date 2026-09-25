# Save Myoko's Hyprland windows and relaunch them at the next graphical login.
# This does not save application data or unsaved edits.
{ inputs, ... }:
{
  nixos.modules.myoko-session-restore =
    { config, pkgs, ... }:
    let
      # Pin upstream through flake.lock. Patch its CLI calls for Myoko's Lua
      # Hyprland instance, preserve the last non-empty snapshot, and use
      # Myoko's own web-app and Chromium launchers instead of their internal binaries.
      script = pkgs.runCommand "myoko-hypr-session-restore" { } ''
        install -Dm755 ${inputs.hypr-session-restore}/hypr-session-restore $out/libexec/hypr-session-restore
        substituteInPlace $out/libexec/hypr-session-restore \
          --replace-fail '["hyprctl", "-j", cmd]' '["hyprctl", "--instance", "0", "-j", cmd]' \
          --replace-fail '["hyprctl", "dispatch", lua]' '["hyprctl", "--instance", "0", "dispatch", lua]' \
          --replace-fail 'import time' "$(printf '%s\n' 'import time' 'from urllib.parse import urlsplit')" \
          --replace-fail 'def save():' "$(printf '%s\n' 'def save():' '    os.umask(0o077)')" \
          --replace-fail '    os.makedirs(STATE_DIR, exist_ok=True)' "$(printf '%s\n' '    if not windows:' '        return 0' '    os.makedirs(STATE_DIR, mode=0o700, exist_ok=True)' '    os.chmod(STATE_DIR, 0o700)')" \
          --replace-fail '    "Alacritty": ("alacritty", "--working-directory", "-e"),' "$(printf '%s\n' '    "Alacritty": ("alacritty", "--working-directory", "-e"),' '    "com.mitchellh.ghostty": ("ghostty", "--working-directory=", "-e"),')" \
          --replace-fail '            cmd = [binary, cwd_flag, cwd]' '            cmd = [binary, cwd_flag + cwd] if cwd_flag.endswith("=") else [binary, cwd_flag, cwd]' \
          --replace-fail '        return shlex.join([binary, cwd_flag, cwd])' "$(printf '%s\n' '        cmd = [binary, cwd_flag + cwd] if cwd_flag.endswith("=") else [binary, cwd_flag, cwd]' '        return shlex.join(cmd)')" \
          --replace-fail '    return shlex.join(argv)' "$(printf '%s\n' '    if len(argv) == 1 and " " in argv[0]:' '        argv = shlex.split(argv[0])' '    for arg in argv:' '        if cls.startswith("chrome-") and arg.startswith("--app="):' '            app_url = arg.removeprefix("--app=")' '            parsed = urlsplit(app_url)' '            if parsed.scheme in ("https", "http") and parsed.hostname and cls == f"chrome-{parsed.hostname}__-Default":' '                return shlex.join(["/run/current-system/sw/bin/web-app", app_url])' '    if cls == "chromium-browser" and "chromium-unwrapped-" in argv[0] and argv[0].endswith("/libexec/chromium/chromium"):' '        argv[0] = "/run/current-system/sw/bin/chromium"' '    return shlex.join(argv)')"
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
          Restart = "on-failure";
          RestartSec = 2;
        };
      };
    };
}
