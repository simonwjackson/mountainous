# The browser spine: CDP control in QML for Ctrl+L and one-window-per-page.
# See docs/decisions/browser-cdp.md for design rationale and measured edge cases.
{
  nixos.modules.desktop =
    { pkgs, ... }:
    {
      hjem.users.simon.files.".config/quickshell/mountainous/CdpBrowser.qml".source =
        ./quickshell/CdpBrowser.qml;

      # CdpBrowser requires QtWebSockets. Expose it on the quickshell service
      # directly so browser.nix owns its own runtime dependency.
      systemd.user.services.quickshell.environment.QML2_IMPORT_PATH =
        "${pkgs.qt6.qtwebsockets}/lib/qt-6/qml";
    };
}
