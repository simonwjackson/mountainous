import Quickshell
import Quickshell.Io
import QtQuick

// What this machine is, for every theme's About view (Platinum's About
// <host>, Win98's System Properties): the host name, the DMI product
// name, the NixOS version and configuration revision (nixos-version
// --json), the system generation and the uptime. Read when it is created;
// the uptime again each minute while `live` is true. Theme-neutral.
Scope {
    id: facts

    property bool live: true

    property string host: ""
    property string product: ""
    property var version: ({})
    property string generation: ""
    property real uptime: -1

    FileView { path: "/proc/sys/kernel/hostname"; blockLoading: true; printErrors: false
        onLoaded: facts.host = text().trim() }
    FileView { path: "/sys/class/dmi/id/product_name"; blockLoading: true; printErrors: false
        onLoaded: facts.product = text().trim() }
    FileView { id: uptimeFile; path: "/proc/uptime"; blockLoading: true; printErrors: false
        onLoaded: facts.uptime = parseFloat(text().split(" ")[0]) }
    Timer { interval: 60000; repeat: true; running: facts.live; onTriggered: uptimeFile.reload() }

    Process {
        command: ["nixos-version", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { facts.version = JSON.parse(text); } catch (e) { facts.version = {}; } }
        }
    }
    Process {
        command: ["readlink", "/nix/var/nix/profiles/system"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /system-(\d+)-link/.exec(text);
                facts.generation = m ? m[1] : "";
            }
        }
    }
}
