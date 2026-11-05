# Desktop icons (Hensou Phase 5): the shell draws the icons that Hensou
# Files' desktop provider supplies over $XDG_RUNTIME_DIR/hensou/desktop.sock
# (Hensou docs/design/desktop-icons.md, ADR 0006). The QML lives in
# modules/quickshell (DesktopIcons*.qml, desktop-icons*.js, lettermark.js,
# Lettermark.qml) and is delivered with the rest of the shell (bars.nix).
#
# checks.desktop-icons: the pure policies (selection, keyboard navigation,
# rubber band, confirmations per theme, the session and its resubscribe on
# a display or theme change, context menus) and the lettermark rule.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.desktop-icons = pkgs.runCommand "desktop-icons" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
        node ${./quickshell/lettermark.test.js} ${./quickshell/lettermark.js}
        node ${./quickshell/desktop-icons-model.test.js} ${./quickshell/desktop-icons-model.js} ${./quickshell/lettermark.js}
        touch $out
      '';
    };
}
