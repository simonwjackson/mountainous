import Quickshell
import Quickshell.Io
import QtQuick

// Only the QML event loop proves liveness. Optional services must not own it.
Scope {
    id: root

    readonly property bool watchdog: Quickshell.env("WATCHDOG_USEC") !== ""
    readonly property int watchdogRunningUsec: 2000000
    property bool watchdogArmed: false

    Process {
        id: notify
        command: root.watchdogArmed
            ? ["systemd-notify", "WATCHDOG=1"]
            : ["systemd-notify", "WATCHDOG=1", "WATCHDOG_USEC=" + root.watchdogRunningUsec]
        onExited: function (code) {
            if (code === 0) root.watchdogArmed = true;
            else console.warn("[heartbeat] systemd-notify exited " + code);
        }
    }

    Timer {
        interval: 500
        repeat: true
        triggeredOnStart: true
        running: root.watchdog
        // A ping still waiting for systemd is enough; do not queue another.
        onTriggered: if (!notify.running) notify.running = true
    }

}
