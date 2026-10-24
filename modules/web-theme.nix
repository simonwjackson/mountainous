# Web pages in the desktop theme: Chromium's pages take the active theme's
# type, scroll bars and form controls. Quickshell's WebTheme.qml delivers
# themes/<id>/web.css over CDP; bars.nix already delivers the QML, the
# scripts and the theme folder. See docs/decisions/web-theme.md.
{
  perSystem =
    { pkgs, ... }:
    {
      # The theme-to-stylesheet policy, the in-page script in a fake
      # window, a lint of each theme's web.css, and the body face's family
      # name, which web.css names literally.
      checks.web-theme =
        pkgs.runCommand "web-theme"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.fontconfig
            ];
          }
          ''
            node ${./quickshell/web-theme.test.js} ${./quickshell/web-theme.js} ${./quickshell/web-theme-page.js} ${./quickshell}
            export HOME="$TMPDIR" XDG_CACHE_HOME="$TMPDIR/cache"
            test "$(fc-scan --format '%{family[0]}' ${pkgs.public-sans}/share/fonts/truetype/PublicSans-Regular.ttf)" = "Public Sans"
            touch $out
          '';
    };

  nixos.modules.desktop =
    { pkgs, ... }:
    {
      # The body face for web pages: a Geneva-like grotesque under the SIL
      # Open Font License 1.1. ChicagoFLF (modules/fonts.nix) sets the
      # interface words. Pages reach both by family name through
      # fontconfig, which a strict font-src policy does not block.
      fonts.packages = [ pkgs.public-sans ];

      # WebTheme.qml's CDP auto-attach makes Chromium wait on Quickshell's
      # event loop: while it stalls, a window that a page opens never loads
      # and closing the socket does not release it. WebTheme pings this
      # watchdog every 0.5 s (systemd-notify, so NotifyAccess=all) and its
      # first ping lowers the limit from 20 s (start-up) to 2 s. SIGKILL,
      # not the default SIGABRT: Quickshell's crash handler would show a
      # crash dialog, and a stopped process never handles SIGABRT. The
      # unit's Restart=on-failure brings it back; the new instance resumes
      # the waiting window. See docs/decisions/web-theme.md.
      systemd.user.services.quickshell = {
        path = [ pkgs.systemd ];
        serviceConfig = {
          WatchdogSec = "20s";
          WatchdogSignal = "SIGKILL";
          NotifyAccess = "all";
        };
      };
    };
}
