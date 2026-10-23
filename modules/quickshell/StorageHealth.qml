import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "storage-health.js" as Health

// Storage and service health on the servers, a placeholder until real alert
// monitoring exists. A helper runs a read-only probe over SSH on each host;
// see modules/storage-health.nix. The readout stays quiet while all is well.
Scope {
    id: root
    property bool shown: false
    property bool enabled: Quickshell.env("STORAGE_HEALTH_ENABLED") === "1"
    property var rows: []
    property string sampleState: "loading"
    property double now: Date.now()
    readonly property string state: Health.ageState(sampleState, checkedAt.getTime(), now)
    property var pending: ({output: null, code: null})
    property date checkedAt
    readonly property var issues: rows.filter(function (row) { return row.level !== "ok"; })
    readonly property string worst: {
        if (rows.some(function (row) { return row.level === "bad"; })) return "bad";
        if (issues.length > 0) return "warn";
        return "ok";
    }
    readonly property string label: {
        if (state === "loading") return "Disks ...";
        if (state === "error") return "Disks !";
        if (state === "stale") return "Disks stale";
        if (issues.length === 0) return "Disks ok";
        return "Disks " + issues.length + (issues.length === 1 ? " issue" : " issues");
    }
    readonly property string shortLabel: state === "ready" && issues.length > 0
        ? "DSK " + issues.length : "DSK"
    // The bar's tone. All well stays quiet on purpose: the readout only
    // asks for attention when something is wrong.
    readonly property string tone: {
        if (state === "error" || state === "stale") return "warning";
        if (state !== "ready") return "muted";
        return worst === "bad" ? "danger" : worst === "warn" ? "warning" : "quiet";
    }
    readonly property bool checking: probe.running
    readonly property string statusText: state === "loading" ? "Checking the servers…"
        : state === "error" && rows.length === 0 ? "The check did not run"
        : state === "error" ? "The last check failed. Showing " + Qt.formatTime(checkedAt, "HH:mm")
        : state === "stale" ? "Stale result from " + Qt.formatDateTime(checkedAt, "yyyy-MM-dd HH:mm")
        : "Checked " + Qt.formatTime(checkedAt, "HH:mm") + ", again every 5 minutes"

    function levelColor(level) {
        return level === "bad" ? Theme.menuDanger
            : level === "ok" ? Theme.menuTextSecondary : Theme.menuWarning;
    }

    // Fill the findings list from rows (a harness sets rows directly).
    function setFindings(list) {
        root.rows = list;
        findingsModel.clear();
        for (const row of list) findingsModel.append(row);
    }

    function refresh() {
        if (root.enabled && !probe.running) {
            root.pending = {output: null, code: null};
            probe.running = true;
        }
    }

    function settle() {
        // stdout completion and process exit may arrive in either order.
        if (pending.output === null || pending.code === null) return;
        const sample = pending.code === 0 ? Health.parse(pending.output, Date.now()) : {state: "error"};
        root.sampleState = sample.state;
        if (sample.state === "error") return;
        root.setFindings(sample.rows);
        root.checkedAt = new Date(sample.checkedAt);
        root.now = Date.now();
    }

    ListModel { id: findingsModel }

    Component.onCompleted: refresh()
    onShownChanged: { if (shown) refresh(); }

    Timer {
        interval: 300000
        running: root.enabled
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        running: root.enabled
        repeat: true
        onTriggered: root.now = Date.now()
    }

    Process {
        id: probe
        command: ["storage-health-status"]
        stdout: StdioCollector { onStreamFinished: { root.pending.output = this.text; root.settle(); } }
        stderr: StdioCollector { }
        onExited: function (code) { root.pending.code = code; root.settle(); }
    }

    property Component menu: Component {
        MenuFrame {
            id: frame

            preferredWidth: 400
            title: "Server storage"
            scrolls: findings.scrolls

            headerTrailing: PlatinumButton {
                text: root.checking ? "Checking" : "Check now"
                fixedWidth: PlatinumMetrics.buttonWidth(["Check now", "Checking"])
                enabled: !root.checking
                onClicked: root.refresh()
            }

            // When the servers were checked, said in full: it wraps rather
            // than cut the time off.
            MenuParts.Line {
                rightInset: frame.rightInset
                text: root.statusText
                color: root.state === "error" || root.state === "stale"
                    ? Theme.menuWarning : Theme.menuTextSecondary
                bottomPadding: 4
            }

            MenuParts.Separator { visible: findingsModel.count > 0 }

            // Findings by host. The host is a section label on the text
            // edge; each finding's level is its mark in the gutter and its
            // colour.
            MenuList {
                id: findings
                visible: findingsModel.count > 0
                model: findingsModel
                view.section.property: "host"
                view.section.delegate: MenuParts.Section {
                    required property string section
                    width: ListView.view.width
                    x: Theme.menuTextLeft
                    rightInset: frame.rightInset
                    topPadding: 6
                    text: section
                }

                delegate: Item {
                    id: finding
                    required property string level
                    required property string message
                    width: ListView.view.width
                    height: findingText.implicitHeight + 6

                    PlatinumIcon {
                        x: Theme.menuGutter + (Theme.menuGutterWidth - width) / 2
                        y: 3 + (16 - height) / 2
                        name: finding.level === "ok" ? "check" : finding.level === "bad" ? "dot" : "ring"
                        size: 10
                        color: root.levelColor(finding.level)
                    }

                    Text {
                        id: findingText
                        x: Theme.menuTextLeft
                        y: 3
                        width: parent.width - x - frame.rightInset
                        text: finding.message
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: root.levelColor(finding.level)
                        font.family: Theme.platinumFont
                        font.pixelSize: Theme.platinumSmall
                        font.letterSpacing: Theme.platinumTracking
                        lineHeight: 1.15
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
