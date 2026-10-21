# The Quickshell view of synced notifications: popups and a notification
# centre on every desktop.
#
# notifyd (modules/notifications.nix) owns org.freedesktop.Notifications and
# syncs through ntfy. Quickshell only draws: it reads and writes
# $XDG_RUNTIME_DIR/notify-sync/ui.sock, one JSON object per line, and never
# starts a NotificationServer of its own. shell.qml instantiates the files
# below by name.
#
# packages/notify-sync/schema/ui-socket.v1.json defines every line on that
# socket. The view validates against it at run time through the generated
# notification-schema.js, and the check below holds the view's parser, its
# ops, and the development daemon's output to it.
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

  schemaFile = ../packages/notify-sync/schema/ui-socket.v1.json;

  # The one generator, notification-schema-js.sh, also serves capture.sh.
  schemaJs =
    pkgs:
    pkgs.runCommand "notification-schema.js" { nativeBuildInputs = [ pkgs.bash ]; } ''
      bash ${./quickshell/notification-schema-js.sh} ${schemaFile} > $out
    '';
in
{
  perSystem =
    { pkgs, ... }:
    {
      # The protocol fold and every layout plan, under node, at each
      # threshold; the parser against python jsonschema's verdicts.
      checks.notification-view =
        pkgs.runCommand "notification-view"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              (pkgs.python3.withPackages (ps: [ ps.jsonschema ]))
            ];
          }
          ''
            python3 ${./quickshell/notification-schema-check.py} \
              ${schemaFile} ${./quickshell/notification-dev/fake-notifyd.py} corpus.json
            # The same results in the two most distant zones prove that no
            # readout depends on the machine's zone.
            for zone in UTC Pacific/Kiritimati Etc/GMT+12; do
              TZ=$zone node ${./quickshell/notification-model.test.js} ${./quickshell/notification-model.js} \
                ${schemaFile} corpus.json ${schemaJs pkgs}
            done
            touch $out
          '';
    };

  nixos.modules.desktop =
    { pkgs, ... }:
    {
      hjem.users.simon.files =
        builtins.listToAttrs (
          map (name: {
            name = ".config/quickshell/mountainous/${name}";
            value.source = ./quickshell + "/${name}";
          }) qml
        )
        // {
          ".config/quickshell/mountainous/notification-schema.js".source = schemaJs pkgs;
        };
    };
}
