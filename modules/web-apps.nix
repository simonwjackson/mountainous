# Web apps: Chromium in --app mode, tiled as windows without browser chrome.
# See docs/decisions/web-apps.md for Wayland flags, single-profile architecture, and CDP flags.
#
# A web app is declared here and never installed through Chromium's own
# Install button. The two paths draw different window frames: --app=<url>
# produces a frameless window, while a Chromium-installed PWA (--app-id=<id>)
# always draws Chromium's own client-side title bar. That choice is upstream
# and there is no flag for it. See docs/decisions/web-apps.md.
{
  nixos.modules.desktop =
    { pkgs, ... }:
    let
      # Kept in one place: modules/browser.nix reads DevToolsActivePort from
      # this directory, and the path is baked into both sides.
      profileDir = "$HOME/.local/share/mountainous/browser";

      web-app = pkgs.writeShellApplication {
        name = "web-app";
        runtimeInputs = [ pkgs.chromium ];
        text = ''
          # usage: web-app <url> [extra chromium args...]
          url="''${1:?url required}"
          shift || true

          profile="${profileDir}"
          mkdir -p "$profile"

          exec chromium \
            --app="$url" \
            --ozone-platform=wayland \
            --user-data-dir="$profile" \
            --remote-debugging-port=0 \
            --no-first-run \
            --no-default-browser-check \
            --enable-features=TurnOffStreamingMediaCachingOnBattery,QuickIntensiveWakeUpThrottlingAfterLoading \
            "$@"
        '';
      };
    in
    let
      # One entry per app, in web-apps.json: the desktop icon themes read it
      # too (lib/desktop-art.nix draws each a lettermark per theme). `host`
      # must match the URL's host exactly, because Chromium builds the window
      # class from it.
      webApps = builtins.fromJSON (builtins.readFile ./web-apps.json);

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
          exec = "${web-app}/bin/web-app ${app.url}";
          icon = "webapp-${id}";
          # Observed on hiyori, not guessed:
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
        [
          pkgs.chromium
          web-app
        ]
        ++ pkgs.lib.mapAttrsToList mkWebApp webApps
        ++ pkgs.lib.mapAttrsToList mkWebAppIcon webApps;

      # Correct for anything launched after a fresh login, and harmless for
      # the app entries above, which no longer depend on it.
      environment.sessionVariables.NIXOS_OZONE_WL = "1";
    };
}
