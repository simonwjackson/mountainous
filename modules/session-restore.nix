# Save the desktop and reopen it at the next login. The work runs inside
# Hyprland: hyprland.lua attaches session-restore.lua when this module
# installs it next to the config. See docs/decisions/session-restore.md.
{
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
