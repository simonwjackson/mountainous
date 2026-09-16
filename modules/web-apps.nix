# Web apps: a site that behaves like an application.
#
# Kamoi installs a page as a PWA and lists it in the omni bar under "PWA
# apps". The desktop equivalent is Chromium's --app mode, which draws the page
# with no tab strip, no address bar and no title bar, so Hyprland tiles it like
# any other window. Verified on ridge against chromium 153.
#
# Three things learned the hard way on this machine:
#
#   * --ozone-platform=wayland is required, spelled out. Neither
#     NIXOS_OZONE_WL nor --ozone-platform-hint=auto was enough: a Hyprland
#     session started before the variable existed passes its old environment
#     to every child, and Chromium then picks X11 and exits with
#     "Missing X server or $DISPLAY".
#
#   * Chromium logs "'--ozone-platform=wayland' is not compatible with Vulkan"
#     and then runs anyway. The message is noise, not a failure.
#
#   * --class is IGNORED on Wayland. Chromium always derives the app_id from
#     the URL, so the window class is chrome-<host>__-Default no matter what
#     is passed. The host is therefore written out below and used for
#     startupWMClass, rather than a name of our choosing.
#
# All apps share one profile on purpose: a separate --user-data-dir per app
# would mean logging into Google once per app.
#
# An --app window has no chrome to reveal. Kamoi's Ctrl+L shows a hidden
# address bar; this window never builds one, so it cannot be pointed elsewhere
# through the interface. It can still be driven over the DevTools protocol,
# which is how Kamoi drives page zoom, and how an omni bar would navigate it.
{
  nixos.modules.desktop =
    { pkgs, ... }:
    let
      # One entry per app. `host` must match the URL's host exactly, because
      # Chromium builds the window class from it.
      webApps = {
        reddit = {
          name = "Reddit";
          url = "https://www.reddit.com";
          host = "www.reddit.com";
          letter = "R";
          tint = "#ff4500";
        };
        youtube-music = {
          name = "YouTube Music";
          url = "https://music.youtube.com";
          host = "music.youtube.com";
          letter = "M";
          tint = "#ff0033";
        };
      };

      # An entry with no Icon= makes every icon lookup fail, and the dock logs
      # the failure on each frame it repaints. The site's own favicon needs a
      # download, which a Nix build cannot do without a pinned hash, so each
      # app gets a drawn lettermark instead. It is offline, reproducible, and
      # distinct per app.
      mkWebAppIcon =
        id: app:
        pkgs.writeTextDir "share/icons/hicolor/scalable/apps/webapp-${id}.svg" ''
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
            <rect width="64" height="64" rx="14" fill="${app.tint}"/>
            <text x="32" y="45" text-anchor="middle" fill="#ffffff"
                  font-family="monospace" font-size="38" font-weight="bold">${app.letter}</text>
          </svg>
        '';

      mkWebApp =
        id: app:
        pkgs.makeDesktopItem {
          name = "webapp-${id}";
          desktopName = app.name;
          comment = "${app.name}, as an app window";
          categories = [ "Network" ];
          exec = "${pkgs.chromium}/bin/chromium --app=${app.url} --ozone-platform=wayland";
          icon = "webapp-${id}";
          # Observed on ridge, not guessed:
          #   https://www.reddit.com    -> chrome-www.reddit.com__-Default
          #   https://music.youtube.com -> chrome-music.youtube.com__-Default
          #
          # The dock reads this field to turn a window class into an icon
          # name, so it must stay exact.
          startupWMClass = "chrome-${app.host}__-Default";
        };
    in
    {
      environment.systemPackages =
        [ pkgs.chromium ]
        ++ pkgs.lib.mapAttrsToList mkWebApp webApps
        ++ pkgs.lib.mapAttrsToList mkWebAppIcon webApps;

      # Correct for anything launched after a fresh login, and harmless for
      # the app entries above, which no longer depend on it.
      environment.sessionVariables.NIXOS_OZONE_WL = "1";
    };
}
