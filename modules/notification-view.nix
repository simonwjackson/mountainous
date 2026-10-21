# The Quickshell view of synced notifications: popups and a notification
# centre on every desktop.
#
# notifyd (modules/notifications.nix) owns org.freedesktop.Notifications and
# syncs through ntfy. Quickshell only draws: it reads and writes
# $XDG_RUNTIME_DIR/notify-sync/ui.sock, one JSON object per line, and never
# starts a NotificationServer of its own. shell.qml instantiates the files
# below by name.
#
# The centre opens from the NTF control in the top bar, or with
#   qs -c mountainous ipc call notifications toggle
#
# modules/quickshell/notification-dev/ holds a fake notifyd and the capture
# script for screenshots. Those files are for development and are not
# installed.
let
  qml = [
    "Notifications.qml"
    "NotificationPopups.qml"
    "NotificationCentre.qml"
    "NotificationCard.qml"
    "NotificationButton.qml"
    "notification-model.js"
  ];
in
{
  perSystem =
    { pkgs, ... }:
    {
      # The protocol fold and every layout plan, under node, at each threshold.
      checks.notification-view =
        pkgs.runCommand "notification-view" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
          node ${./quickshell/notification-model.test.js} ${./quickshell/notification-model.js}
          touch $out
        '';
    };

  nixos.modules.desktop = {
    hjem.users.simon.files = builtins.listToAttrs (
      map (name: {
        name = ".config/quickshell/mountainous/${name}";
        value.source = ./quickshell + "/${name}";
      }) qml
    );
  };
}
