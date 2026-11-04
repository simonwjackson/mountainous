# Save the desktop and reopen it at the next login. The work runs inside
# Hyprland: hyprland.lua attaches session-restore.lua when this module
# installs it next to the config. See docs/decisions/session-restore.md.
{
  perSystem =
    { pkgs, ... }:
    {
      checks.hyprland-session-plan =
        pkgs.runCommand "hyprland-session-plan" { nativeBuildInputs = [ pkgs.lua5_5 ]; }
          ''
            export XDG_STATE_HOME="$TMPDIR/state" XDG_RUNTIME_DIR="$TMPDIR/run"
            export MOUNTAINOUS_ROOT=${../.}
            luac -p ${./hyprland/session-plan.lua} ${../scripts/test-hyprland-session.lua}
            lua ${../scripts/test-hyprland-session.lua} --plan-only
            touch "$out"
          '';
    };

  nixos.modules.session-restore = {
    hjem.users.simon.files = {
      ".config/hypr/session-restore.lua".source = ./hyprland/session-restore.lua;
      ".config/hypr/session-plan.lua".source = ./hyprland/session-plan.lua;
    };

    # Lua in the compositor cannot create directories or set modes. The
    # snapshot holds launch commands, which can carry secrets.
    systemd.user.tmpfiles.users.simon.rules = [
      "d %S/mountainous/session 0700 - - -"
    ];
  };
}
