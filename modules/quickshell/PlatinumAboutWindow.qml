import Hensou as Kit
import Quickshell
import Quickshell.Io
import QtQuick

// About <host>…: a Platinum windoid under the bar at the left, never
// centred. SystemFacts reads the host name, the NixOS version and
// generation, the configuration revision (nixos-version --json) and the
// uptime when it opens, and the uptime again each minute while it stays
// open. Memphis's System Properties reads the same.
PanelWindow {
    id: about

    required property var modelData
    signal closeRequested
    screen: modelData

    anchors { top: true; left: true }
    // Drawing Board's crop marks and hatched shadow reach past the frame:
    // the surface grows by that bleed on every side and moves out by it,
    // so the frame stays where it was. Light and Dark grey have none.
    readonly property real bleed: Kit.PlatinumTokens.drafting ? 6 * Kit.PlatinumTokens.hairFor(QsWindow.window) : 0
    margins { top: 22 - bleed; left: 24 - bleed }
    // Room for the windoid's hard shadow, one rule down and right.
    implicitWidth: Math.min(frame.implicitWidth, (modelData ? modelData.width : 1920) - 32) + 2 * Kit.PlatinumTokens.hairFor(QsWindow.window) + 2 * bleed
    implicitHeight: frame.implicitHeight + 2 * Kit.PlatinumTokens.hairFor(QsWindow.window) + 2 * bleed
    exclusionMode: ExclusionMode.Normal
    focusable: true
    color: "transparent"

    // The facts, from the reader every theme's About view shares.
    SystemFacts { id: systemFacts; live: about.visible }
    readonly property string host: systemFacts.host
    readonly property string product: systemFacts.product
    readonly property var version: systemFacts.version
    readonly property string generation: systemFacts.generation
    readonly property real uptime: systemFacts.uptime

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

    PlatinumDialogFrame {
        id: frame
        x: about.bleed
        y: about.bleed
        width: about.width - 2 * Kit.PlatinumTokens.hairFor(QsWindow.window) - 2 * about.bleed
        height: about.height - 2 * Kit.PlatinumTokens.hairFor(QsWindow.window) - 2 * about.bleed
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
                    color: Kit.PlatinumTokens.menuText
                    knock: Kit.PlatinumTokens.menuSurface
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: about.capitalised(about.host) || "This Computer"
                        color: Kit.PlatinumTokens.menuText
                        font.family: Kit.PlatinumTokens.platinumFont
                        font.pixelSize: 18
                        font.letterSpacing: Kit.PlatinumTokens.platinumTracking
                    }
                    Text {
                        visible: about.product !== ""
                        text: about.product
                        textFormat: Text.PlainText
                        color: Kit.PlatinumTokens.menuTextSecondary
                        font.family: Kit.PlatinumTokens.platinumFont
                        font.pixelSize: Kit.PlatinumTokens.platinumSmall
                        font.letterSpacing: Kit.PlatinumTokens.platinumTracking
                    }
                }
            }

            Grid {
                id: facts
                columns: 2
                columnSpacing: 14
                rowSpacing: 5
                readonly property real keyWidth: Kit.PlatinumMetrics.smallWidest(["Revision", "Uptime", "NixOS", "Host"])
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
                        color: isKey ? Kit.PlatinumTokens.menuTextSecondary : Kit.PlatinumTokens.menuText
                        font.family: Kit.PlatinumTokens.platinumFont
                        font.pixelSize: Kit.PlatinumTokens.platinumSmall
                        font.letterSpacing: Kit.PlatinumTokens.platinumTracking
                    }
                }
            }
        }
    }
}
