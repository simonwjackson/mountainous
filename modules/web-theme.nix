# Web pages in the desktop theme: Chromium's pages take the active theme's
# type, scroll bars and form controls. Quickshell's WebTheme.qml delivers
# themes/<id>/web.css over CDP; bars.nix already delivers the QML, the
# scripts and the theme folder. See docs/decisions/web-theme.md.
{ inputs, ... }:
{
  perSystem =
    { pkgs, config, ... }:
    {
      # The theme-to-stylesheet policy, the in-page script in a fake
      # window, a lint of each theme's web.css, and the family names the
      # sheets name literally: Platinum's body face, Win98's W95FA Grid.
      checks.web-theme =
        pkgs.runCommand "web-theme"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.fontconfig
            ];
          }
          ''
            HENSOU_QML_ROOT=${inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system}.hensou-qml}/lib/qt-6/qml node ${./quickshell/web-theme.test.js} ${./quickshell/web-theme.js} ${./quickshell/web-theme-page.js} ${./quickshell}
            export HOME="$TMPDIR" XDG_CACHE_HOME="$TMPDIR/cache"
            test "$(fc-scan --format '%{family[0]}' ${pkgs.public-sans}/share/fonts/truetype/PublicSans-Regular.ttf)" = "Public Sans"
            test "$(fc-scan --format '%{family[0]}' ${config.packages.w95fa-grid}/share/fonts/truetype/W95FAGrid.ttf)" = "W95FA Grid"
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

      # The root Heartbeat owns the watchdog in bars.nix, not this feature.
    };
}
