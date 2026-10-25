import Quickshell
import Quickshell.Io
import QtQuick

// About <host>…: a Platinum windoid under the bar at the left, never
// centred. It reads the host name, the NixOS version and generation, the
// configuration revision (nixos-version --json) and the uptime when it
// opens, and the uptime again each minute while it stays open.
PanelWindow {
    id: about

    required property var modelData
    signal closeRequested
    screen: modelData

    anchors { top: true; left: true }
    margins { top: 22; left: 24 }
    // Room for the windoid's hard shadow, one rule down and right.
    implicitWidth: Math.min(frame.implicitWidth, (modelData ? modelData.width : 1920) - 32) + 2 * PlatinumTokens.hair
    implicitHeight: frame.implicitHeight + 2 * PlatinumTokens.hair
    exclusionMode: ExclusionMode.Normal
    focusable: true
    color: "transparent"

    property string host: ""
    property string product: ""
    property var version: ({})
    property string generation: ""
    property real uptime: -1

    function capitalised(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : ""; }
    function uptimeText(seconds) {
        if (!(seconds >= 0)) return "Unknown";
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor(seconds % 86400 / 3600);
        const minutes = Math.floor(seconds % 3600 / 60);
        const clock = hours + ":" + (minutes < 10 ? "0" : "") + minutes;
        return days > 0 ? days + (days === 1 ? " day, " : " days, ") + clock : clock;
    }
    readonly property var lines: [
        ["Host", about.host || "Unknown"],
        ["NixOS", (about.version.nixosVersion || "Unknown") + (about.generation !== "" ? ", generation " + about.generation : "")],
        ["Revision", about.version.configurationRevision || "Not recorded"],
        ["Uptime", about.uptimeText(about.uptime)]
    ]

    FileView { path: "/proc/sys/kernel/hostname"; blockLoading: true; printErrors: false
        onLoaded: about.host = text().trim() }
    FileView { path: "/sys/class/dmi/id/product_name"; blockLoading: true; printErrors: false
        onLoaded: about.product = text().trim() }
    FileView { id: uptimeFile; path: "/proc/uptime"; blockLoading: true; printErrors: false
        onLoaded: about.uptime = parseFloat(text().split(" ")[0]) }
    Timer { interval: 60000; repeat: true; running: about.visible; onTriggered: uptimeFile.reload() }

    Process {
        command: ["nixos-version", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { about.version = JSON.parse(text); } catch (e) { about.version = {}; } }
        }
    }
    Process {
        command: ["readlink", "/nix/var/nix/profiles/system"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /system-(\d+)-link/.exec(text);
                about.generation = m ? m[1] : "";
            }
        }
    }

    PlatinumDialogFrame {
        id: frame
        width: about.width - 2 * PlatinumTokens.hair
        height: about.height - 2 * PlatinumTokens.hair
        title: "About " + (about.capitalised(about.host) || "This Computer")
        onCloseRequested: about.closeRequested()
        focus: true
        Keys.onEscapePressed: about.closeRequested()

        Column {
            width: Math.max(200, Math.min(420, (about.modelData ? about.modelData.width : 1920) - 80))
            spacing: 12

            Row {
                spacing: 14
                PlatinumIcon {
                    width: 54
                    height: 48
                    name: "mark"
                    color: PlatinumTokens.menuText
                    knock: PlatinumTokens.menuSurface
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: about.capitalised(about.host) || "This Computer"
                        color: PlatinumTokens.menuText
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: 18
                        font.letterSpacing: PlatinumTokens.platinumTracking
                    }
                    Text {
                        visible: about.product !== ""
                        text: about.product
                        textFormat: Text.PlainText
                        color: PlatinumTokens.menuTextSecondary
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumSmall
                        font.letterSpacing: PlatinumTokens.platinumTracking
                    }
                }
            }

            Grid {
                id: facts
                columns: 2
                columnSpacing: 14
                rowSpacing: 5
                readonly property real keyWidth: PlatinumMetrics.smallWidest(["Revision", "Uptime", "NixOS", "Host"])
                Repeater {
                    model: about.lines.length * 2
                    Text {
                        required property int index
                        readonly property var line: about.lines[Math.floor(index / 2)]
                        readonly property bool isKey: index % 2 === 0
                        width: isKey ? facts.keyWidth : Math.max(0, facts.parent.width - facts.keyWidth - facts.columnSpacing)
                        text: isKey ? line[0] : line[1]
                        textFormat: Text.PlainText
                        wrapMode: isKey ? Text.NoWrap : Text.WrapAnywhere
                        color: isKey ? PlatinumTokens.menuTextSecondary : PlatinumTokens.menuText
                        font.family: PlatinumTokens.platinumFont
                        font.pixelSize: PlatinumTokens.platinumSmall
                        font.letterSpacing: PlatinumTokens.platinumTracking
                    }
                }
            }
        }
    }
}
