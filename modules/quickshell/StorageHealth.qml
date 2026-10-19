import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Storage and service health on the servers, a placeholder until real alert
// monitoring exists. A helper runs a read-only probe over SSH on each host;
// see modules/storage-health.nix. The readout stays quiet while all is well.
Scope {
    id: root
    required property var screen
    property bool shown: false
    signal closeRequested
    readonly property bool enabled: Quickshell.env("STORAGE_HEALTH_ENABLED") === "1"
    property var rows: []
    property string state: "loading"
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
        if (issues.length === 0) return "Disks ok";
        return "Disks " + issues.length + (issues.length === 1 ? " issue" : " issues");
    }
    readonly property string shortLabel: state === "ready" && issues.length > 0
        ? "DSK " + issues.length : "DSK"
    readonly property color statusColor: {
        if (state === "error") return Theme.warning;
        if (state !== "ready") return Theme.textMuted;
        return worst === "bad" ? Theme.danger : worst === "warn" ? Theme.warning : Theme.textMuted;
    }

    function levelColor(level) {
        return level === "bad" ? Theme.danger
            : level === "ok" ? Theme.textSecondary : Theme.warning;
    }

    function refresh() {
        if (root.enabled && !probe.running) probe.running = true;
    }

    function accept(value) {
        const next = [];
        for (const line of value.trim().split("\n")) {
            const fields = line.split("\t");
            if (fields.length !== 3) continue;
            next.push({host: fields[0], level: fields[1], message: fields[2]});
        }
        if (next.length === 0) {
            root.state = "error";
            return;
        }
        root.rows = next;
        // ListView sections need model roles, which a JS array lacks.
        findingsModel.clear();
        for (const row of next) findingsModel.append(row);
        root.checkedAt = new Date();
        root.state = "ready";
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

    Process {
        id: probe
        command: ["storage-health-status"]
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
                width: Math.min(380, Math.max(0, veil.width - 12))
                // Grow with the findings, up to what the screen allows.
                height: Math.max(0, Math.min(content.implicitHeight + 24, veil.height - 44))
                radius: Theme.radiusLarge
                color: Theme.bgPanel
                border.width: 1
                border.color: Theme.borderMuted
                MouseArea { anchors.fill: parent }
                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Server storage"
                            color: Theme.textPrimary
                            font.pixelSize: 14
                            font.family: Theme.fontFamily
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            Layout.preferredWidth: checkNow.implicitWidth + 12
                            Layout.preferredHeight: 22
                            radius: Theme.radiusSmall
                            color: checkArea.containsMouse ? Theme.bgSelected : "transparent"
                            Text {
                                id: checkNow
                                anchors.centerIn: parent
                                text: probe.running ? "Checking" : "Check now"
                                color: probe.running ? Theme.textMuted : Theme.accent
                                font.pixelSize: 11
                                font.family: Theme.fontFamily
                            }
                            MouseArea {
                                id: checkArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.refresh()
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.state === "loading" ? "Checking the servers…"
                            : root.state === "error" && root.rows.length === 0 ? "The check did not run"
                            : root.state === "error" ? "The last check failed. Showing "
                                + Qt.formatTime(root.checkedAt, "HH:mm")
                            : "Checked " + Qt.formatTime(root.checkedAt, "HH:mm")
                                + ", again every 5 minutes"
                        color: Theme.textSecondary
                        font.pixelSize: 11
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                    }
                    ListView {
                        id: findings
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: contentHeight
                        clip: true
                        spacing: 2
                        model: findingsModel
                        boundsBehavior: Flickable.StopAtBounds
                        // Shows that more findings exist below the fold.
                        ScrollIndicator.vertical: ScrollIndicator { }
                        section.property: "host"
                        section.delegate: Text {
                            required property string section
                            width: findings.width
                            topPadding: 6
                            text: section
                            color: Theme.textPrimary
                            font.pixelSize: 12
                            font.family: Theme.fontFamily
                            font.bold: true
                        }
                        delegate: Text {
                            required property string level
                            required property string message
                            width: findings.width
                            leftPadding: 10
                            text: message
                            color: root.levelColor(level)
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                            wrapMode: Text.Wrap
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Esc or click outside to close"
                        color: Theme.textMuted
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                        elide: Text.ElideRight
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.WindowShortcut
                onActivated: root.closeRequested()
            }
        }
    }
}
