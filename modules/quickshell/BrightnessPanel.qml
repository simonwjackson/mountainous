import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// The brightness panel, reached from the top bar or with SUPER+O then L.
// Built to the same shape as SoundPanel: a Scope that owns the state, a
// LazyLoader that builds the window only while it is shown, a veil with a
// Hyprland focus grab, and one card under the bar.
//
// There is one level for every screen. modules/brightness.py owns it:
//   ~/.local/state/mountainous/brightness      the level, a percentage
//   $XDG_RUNTIME_DIR/mountainous-brightness.json
//       { "panel": bool, "monitors": [{ "manufacturer", "model" }] }
//       the screens that follow the level, rewritten at each rescan
// This panel only reads those files. Every change goes through
// `mountainous-brightness`, the same command the brightness keys run, so the
// keys, the bar and the panel cannot disagree.
Scope {
    id: root

    required property var screen
    property bool shown: false
    signal closeRequested

    // modules/brightness.py: MINIMUM and MAXIMUM.
    readonly property int minimum: 5
    readonly property int maximum: 100

    // The stored level, as the level file says. Every screen follows it.
    property int level: -1

    // What the bar and the slider draw. While a drag is held, or while a
    // value it sent is still on its way to the file, that is the value the
    // user asked for, not the file: the file lags the pointer, and drawing it
    // made the fill jump back and forth during a drag.
    readonly property int shownLevel:
        (root.dragging || root.sending || settle.running) && root.requested >= 0
            ? root.requested : root.level

    // The last write lands in the file a moment after its process exits.
    // Hold the requested value until the file has caught up, so the fill
    // does not flick back to an older step on release.
    Timer {
        id: settle
        interval: 400
    }
    onLevelChanged: if (root.level === root.requested) settle.stop()

    property bool panelFollows: false
    property var monitors: []

    // What the top bar reads. Hidden only when no screen can be dimmed,
    // because then the control has nothing to do.
    readonly property bool available: root.level >= 0
        && (root.panelFollows || root.monitors.length > 0)

    readonly property string stateDir: {
        const x = Quickshell.env("XDG_STATE_HOME");
        return (x && x !== "") ? x : Quickshell.env("HOME") + "/.local/state";
    }

    FileView {
        path: root.stateDir + "/mountainous/brightness"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const value = parseInt(text().trim(), 10);
            if (!isNaN(value)) root.level = value;
        }
    }

    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/mountainous-brightness.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            // A read can land mid-write. Keep the last good value.
            try {
                const status = JSON.parse(text());
                root.panelFollows = status.panel === true;
                root.monitors = Array.isArray(status.monitors) ? status.monitors : [];
            } catch (e) {}
        }
    }

    function run(args) {
        Quickshell.execDetached(["mountainous-brightness"].concat(args));
    }

    function step(direction) { root.run([direction > 0 ? "up" : "down"]); }

    // A drag sends its values through one process at a time. A value that
    // arrives while one is running waits, and only the newest waiting value
    // is sent next. Separate processes for each step could finish out of
    // order, so the level could end on a step the pointer had already left.
    property bool dragging: false
    property int requested: -1
    property int pending: -1
    readonly property bool sending: setter.running || root.pending >= 0

    Process {
        id: setter
        onExited: {
            root.flush();
            if (!root.sending) settle.restart();
        }
    }

    function flush() {
        if (setter.running || root.pending < 0) return;
        setter.command = ["mountainous-brightness", "set", String(root.pending)];
        root.pending = -1;
        setter.running = true;
    }

    function setLevel(value) {
        const v = Math.max(root.minimum, Math.min(root.maximum, Math.round(value)));
        if (v === root.requested && root.sending) return;
        root.requested = v;
        root.pending = v;
        root.flush();
    }

    // The laptop panel is an eDP output. An external screen follows when the
    // daemon reached a monitor with its model over DDC/CI.
    function follows(screen) {
        if (!screen) return false;
        if (screen.name.startsWith("eDP")) return root.panelFollows;
        return root.monitors.some(function (m) { return m.model !== "" && m.model === screen.model; });
    }

    function screenLabel(screen) {
        if (screen.name.startsWith("eDP")) return "Laptop screen";
        return screen.model !== "" ? screen.model : screen.name;
    }

    // Every connected screen, plus any monitor the daemon reaches that is
    // not a screen here, such as one showing another computer's input.
    readonly property var rows: {
        const list = Quickshell.screens.map(function (s) {
            return { label: root.screenLabel(s), detail: s.name, follows: root.follows(s) };
        });
        for (const m of root.monitors) {
            const shownHere = Quickshell.screens.some(function (s) { return s.model === m.model; });
            if (!shownHere) list.push({
                label: m.model || "Monitor",
                detail: "not showing this computer",
                follows: true
            });
        }
        return list;
    }

    // Layout is a pure function of the veil's size. Height decides structure,
    // width decides content. The level row is the control and always renders;
    // the hint and the per-row output name are readouts and yield first.
    function layoutPlan(width, height) {
        const cardWidth = Math.min(340, Math.max(0, width - 12));
        const rowHeight = 40;
        const showHint = height >= 260;
        const content = 30 + 6 + 40 + 6 + 1 + 6 + root.rows.length * (rowHeight + 2)
            + (showHint ? 6 + 22 : 0) + 20;
        return {
            cardWidth: cardWidth,
            cardHeight: Math.min(content, Math.max(150, height - 44)),
            rowHeight: rowHeight,
            showDetail: cardWidth >= 280,
            showHint: showHint
        };
    }

    LazyLoader {
        active: root.shown

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

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeRequested()
            }

            Rectangle {
                id: card

                readonly property var plan: root.layoutPlan(veil.width, veil.height)

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 32
                anchors.rightMargin: 6
                width: plan.cardWidth
                height: plan.cardHeight
                radius: Theme.radiusLarge
                color: Theme.bgPanel
                border.width: 1
                border.color: Theme.borderMuted

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: "Brightness"
                            color: Theme.textPrimary
                            font.pixelSize: 14
                            font.family: Theme.fontFamily
                            font.bold: true
                        }

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: Theme.radiusSmall
                            color: closeArea.containsMouse ? Theme.bgSelected : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: Theme.textSecondary
                                font.pixelSize: 16
                                font.family: Theme.fontFamily
                            }

                            MouseArea {
                                id: closeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.closeRequested()
                            }
                        }
                    }

                    // The one level. The track's left end is the dim minimum,
                    // not zero, so the full drag is the full range the keys
                    // can reach.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        spacing: 8

                        Text {
                            Layout.preferredWidth: 38
                            horizontalAlignment: Text.AlignRight
                            text: root.shownLevel >= 0 ? root.shownLevel + "%" : "--"
                            color: Theme.textPrimary
                            font.pixelSize: 12
                            font.family: Theme.fontFamily
                        }

                        Rectangle {
                            id: track

                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: Theme.bgSeparator

                            readonly property real ratio: root.shownLevel < 0 ? 0
                                : (root.shownLevel - root.minimum) / (root.maximum - root.minimum)

                            Rectangle {
                                width: Math.round(parent.width * Math.min(1, Math.max(0, track.ratio)))
                                height: parent.height
                                radius: parent.radius
                                color: Theme.accent
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.topMargin: -12
                                anchors.bottomMargin: -12

                                function setFromX(x) {
                                    const ratio = Math.min(1, Math.max(0, x / track.width));
                                    root.setLevel(root.minimum + ratio * (root.maximum - root.minimum));
                                }

                                onPressed: function (mouse) {
                                    root.dragging = true;
                                    setFromX(mouse.x);
                                }
                                onPositionChanged: function (mouse) {
                                    if (pressed) setFromX(mouse.x);
                                }
                                onReleased: root.dragging = false
                                onCanceled: root.dragging = false
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.bgSeparator
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: ScriptModel { values: root.rows }

                        delegate: Item {
                            required property var modelData

                            width: ListView.view.width
                            height: card.plan.rowHeight

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                Text {
                                    Layout.preferredWidth: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData.follows ? "●" : "○"
                                    color: modelData.follows ? Theme.accent : Theme.textDim
                                    font.pixelSize: 11
                                    font.family: Theme.fontFamily
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        elide: Text.ElideRight
                                        color: modelData.follows ? Theme.textPrimary : Theme.textMuted
                                        font.pixelSize: 12
                                        font.family: Theme.fontFamily
                                    }

                                    // Why a screen does not follow is the
                                    // one fact a user can act on, so it
                                    // stays when the output name yields.
                                    Text {
                                        Layout.fillWidth: true
                                        visible: card.plan.showDetail || !modelData.follows
                                        text: modelData.follows
                                            ? modelData.detail
                                            : "Keeps its own brightness"
                                        elide: Text.ElideRight
                                        color: Theme.textDetail
                                        font.pixelSize: 10
                                        font.family: Theme.fontFamily
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        visible: card.plan.showHint
                        text: "←→ brightness · Esc close"
                        elide: Text.ElideRight
                        color: Theme.textDetail
                        font.pixelSize: 9
                        font.family: Theme.fontFamily
                    }
                }
            }

            Shortcut {
                sequence: "Left"
                context: Qt.WindowShortcut
                onActivated: root.step(-1)
            }

            Shortcut {
                sequence: "Right"
                context: Qt.WindowShortcut
                onActivated: root.step(1)
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.WindowShortcut
                onActivated: root.closeRequested()
            }
        }
    }
}
