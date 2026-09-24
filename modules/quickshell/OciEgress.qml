import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// OCI's monthly Outbound Data Transfer Zone 1 usage. Quickshell owns the
// readout; a separate helper holds the credentials and API request.
Scope {
    id: root
    required property var screen
    property bool shown: false
    signal closeRequested
    readonly property bool enabled: Quickshell.env("OCI_EGRESS_ENABLED") === "1"
    property var rows: []
    property string state: "loading"
    readonly property string label: {
        if (state === "unavailable") return "OCI --";
        if (state === "loading") return "OCI ...";
        if (state === "error") return "OCI !";
        return "OCI " + rows.map(function (row) {
            return row.name + ":" + row.percent + "%";
        }).join(" ");
    }
    readonly property color statusColor: {
        if (state !== "ready") return Theme.textMuted;
        let max = 0;
        for (const row of rows) {
            const value = Number(row.percent);
            if (Number.isFinite(value)) max = Math.max(max, value);
        }
        return max >= 80 ? Theme.danger : max >= 50 ? Theme.warning : Theme.accent;
    }

    function refresh() {
        if (root.enabled && !usage.running) usage.running = true;
    }

    function accept(value) {
        const lines = value.trim().split("\n");
        if (lines.length === 1 && lines[0] === "unavailable") {
            root.state = "unavailable";
            root.rows = [];
            return;
        }
        const next = [];
        for (const line of lines) {
            const fields = line.split("\t");
            if (fields.length !== 4) continue;
            next.push({name: fields[0], percent: fields[1], used: fields[2], projected: fields[3]});
        }
        root.rows = next;
        root.state = next.length && next.some(function (row) { return row.percent !== "--"; })
            ? "ready" : "error";
    }

    Component.onCompleted: refresh()
    onShownChanged: { if (shown) refresh(); }

    Timer {
        interval: 3600000
        running: root.enabled
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: usage
        command: ["oci-egress-status"]
        stdout: StdioCollector { onStreamFinished: root.accept(this.text) }
        stderr: StdioCollector { }
        onExited: function (code) { if (code !== 0) root.state = "error"; }
    }

    LazyLoader {
        active: root.shown && root.enabled
        PanelWindow {
            id: veil
            screen: root.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            color: "transparent"
            HyprlandFocusGrab {
                active: root.shown
                windows: [ veil ]
                onCleared: root.closeRequested()
            }
            MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 32
                anchors.rightMargin: 6
                width: Math.min(310, Math.max(0, veil.width - 12))
                height: Math.max(0, Math.min(280, veil.height - 44))
                radius: Theme.radiusLarge
                color: Theme.bgPanel
                border.width: 1
                border.color: Theme.borderMuted
                MouseArea { anchors.fill: parent }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Text {
                        text: "OCI egress · this month"
                        color: Theme.textPrimary
                        font.pixelSize: 14
                        font.family: Theme.fontFamily
                        font.bold: true
                    }
                    Text {
                        visible: root.state !== "ready"
                        text: root.state === "loading" ? "Loading usage…" :
                            root.state === "unavailable" ? "OCI credentials unavailable" : "Usage request failed"
                        color: Theme.textSecondary
                        font.pixelSize: 11
                        font.family: Theme.fontFamily
                    }
                    Repeater {
                        model: root.rows
                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: modelData.name + "  " + modelData.percent + "%"
                                color: modelData.percent === "--" ? Theme.textMuted : root.statusColor
                                font.pixelSize: 12
                                font.family: Theme.fontFamily
                            }
                            Text {
                                text: modelData.used === "--" ? "Usage request failed" :
                                    modelData.used + " GB / 10240 GB · projected " + modelData.projected + " GB"
                                color: Theme.textSecondary
                                font.pixelSize: 10
                                font.family: Theme.fontFamily
                                elide: Text.ElideRight
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: "Esc or click outside to close"
                        color: Theme.textMuted
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                    }
                }
            }
        }
    }
}
