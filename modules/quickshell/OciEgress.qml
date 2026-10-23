import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "oci-model.js" as OciModel

// OCI's monthly Outbound Data Transfer Zone 1 usage. Quickshell owns the
// readout; a separate helper holds the credentials and API request.
// Each profile has its own tone and its own failed label (OciModel.rowRule).
Scope {
    id: root
    property bool shown: false
    property bool enabled: Quickshell.env("OCI_EGRESS_ENABLED") === "1"
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
    readonly property var ruledRows: root.rows.map(function (row) { return OciModel.rowRule(row); })
    // The bar icon's tone: the worst profile's, or muted while there is
    // no usage to show.
    readonly property string tone: {
        if (state !== "ready") return "muted";
        const tones = root.ruledRows.map(function (r) { return r.tone; });
        if (tones.indexOf("danger") >= 0) return "danger";
        if (tones.indexOf("warning") >= 0) return "warning";
        return "normal";
    }
    readonly property string stateText: state === "loading" ? "Loading usage…"
        : state === "unavailable" ? "OCI credentials unavailable"
        : state === "error" ? "Usage request failed"
        : "Outbound data, Zone 1"

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

    property Component menu: Component {
        MenuFrame {
            id: frame

            preferredWidth: 420
            title: "OCI egress · this month"
            detail: root.stateText
            scrolls: profiles.scrolls

            readonly property real valueWidth: PlatinumMetrics.widest(["100.0%", "Failed"])

            // Profiles scroll: a tenancy with many no longer clips.
            MenuList {
                id: profiles
                visible: root.rows.length > 0
                model: ScriptModel { values: root.rows }

                delegate: MenuListRow {
                    id: profileRow
                    required property var modelData
                    readonly property var rule: OciModel.rowRule(modelData)
                    width: ListView.view.width
                    rightInset: frame.rightInset
                    name: rule.name
                    detail: rule.failed ? "Usage request failed"
                        : modelData.used + " GB / 10240 GB · projected " + modelData.projected + " GB"
                    detailColor: rule.failed ? Theme.menuTextSecondary : Theme.menuTextSecondary

                    // The profile's own tone, on its own value.
                    Text {
                        width: frame.valueWidth
                        horizontalAlignment: Text.AlignRight
                        text: profileRow.rule.value
                        color: Theme.menuTone(profileRow.rule.tone)
                        font.family: Theme.platinumFont
                        font.pixelSize: Theme.platinumText
                        font.letterSpacing: Theme.platinumTracking
                    }
                }
            }

            MenuParts.Hint {
                rightInset: frame.rightInset
                text: "Esc or click outside to close"
            }
        }
    }
}
