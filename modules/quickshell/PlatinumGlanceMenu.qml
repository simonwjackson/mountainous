import QtQuick
import QtQuick.Layouts
import "glance-registry.js" as Registry
import "beszel-model.js" as Model

// The Glance menu, hung from the bar's Fleet readout: show or hide the
// glance space, open the Fleet window, Clean Up, and a check box per glance
// widget. Its header carries the fleet's summary in full, so the readout's
// count can yield on a narrow bar without being lost.
PlatinumMenuFrame {
    id: frame

    required property var desktop
    required property var beszel

    preferredWidth: 300
    title: "Glance"
    detail: frame.beszel ? Model.summaryVariants(frame.beszel.fleet, true, "Fleet: ")[0] : ""
    detailColor: !frame.beszel || frame.beszel.fleet.state !== "ready" ? PlatinumTokens.menuTextSecondary
        : frame.beszel.fleet.problems.some(function (v) { return v.tone === "danger"; }) ? PlatinumTokens.menuDanger
        : frame.beszel.fleet.problems.length ? PlatinumTokens.menuWarning : PlatinumTokens.menuTextSecondary

    readonly property bool glanceShown: GlanceState.glanceScreen === frame.desktop.screen
    readonly property bool fleetShown: GlanceState.fleetScreen === frame.desktop.screen
    readonly property var entries: {
        const out = [
            {id: "glance", label: frame.glanceShown ? "Hide Glance" : "Show Glance", key: "Super+W", enabled: true},
            {id: "fleet-window", label: frame.fleetShown ? "Close Fleet Window" : "Open Fleet Window", key: "Super+B", enabled: true},
            {id: "cleanup", label: "Clean Up", key: "", enabled: GlanceState.hasPlaces}
        ];
        for (const id of Registry.ids()) out.push({id: "widget:" + id, widget: id, label: Registry.label(id), key: "", enabled: true});
        return out;
    }
    property int current: -1

    // Where the zoom rects start or end: this row, in screen coordinates
    // (the menu window covers the screen).
    function rectOf(item) {
        const p = item.mapToItem(null, 0, 0);
        return {x: p.x, y: p.y, w: item.width, h: item.height};
    }

    function run(index, item) {
        const e = frame.entries[index];
        if (!e || !e.enabled) return;
        if (e.widget) { GlanceState.setEnabled(e.widget, !GlanceState.enabled(e.widget)); return; }
        const from = item ? frame.rectOf(item) : null;
        MenuState.close();
        if (e.id === "glance") frame.desktop.toggleGlance(from);
        else if (e.id === "fleet-window") frame.desktop.openFleetWindow();
        else if (e.id === "cleanup") GlanceState.cleanUp();
    }

    function step(delta) {
        const n = frame.entries.length;
        let i = frame.current;
        for (let k = 0; k < n; k++) {
            i = (i + delta + n) % n;
            if (frame.entries[i].enabled) { frame.current = i; return; }
        }
    }

    function cancel() { return false; }

    focus: true
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Down) { frame.step(1); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { frame.step(-1); event.accepted = true; }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (frame.current >= 0) frame.run(frame.current, rows.itemAt(frame.current));
            event.accepted = true;
        }
    }

    component Entry: Item {
        id: entry
        required property var modelData
        required property int index
        readonly property bool selected: frame.current === index && modelData.enabled
        readonly property bool isWidget: modelData.widget !== undefined
        // The first widget check starts a group: an etched rule and a label.
        readonly property bool opensGroup: isWidget && index > 0 && frame.entries[index - 1].widget === undefined
        readonly property real lineH: PlatinumTokens.menuLine + 2
        readonly property real groupH: opensGroup ? separator.implicitHeight + section.implicitHeight : 0
        Layout.fillWidth: true
        Layout.preferredHeight: lineH + groupH
        implicitHeight: lineH + groupH

        PlatinumMenuParts.Separator {
            id: separator
            visible: entry.opensGroup
            width: parent.width
        }
        PlatinumMenuParts.Section {
            id: section
            visible: entry.opensGroup
            y: separator.implicitHeight
            x: PlatinumTokens.menuTextLeft
            width: parent.width - x - frame.rightInset
            text: "Glance widgets"
        }

        Item {
            id: line
            y: entry.groupH
            width: parent.width
            height: entry.lineH

            Rectangle {
                anchors.fill: parent
                visible: entry.selected
                color: PlatinumTokens.highlight
            }
            PlatinumCheckBox {
                visible: entry.isWidget
                x: PlatinumTokens.menuGutter + (PlatinumTokens.menuGutterWidth - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                checked: entry.isWidget && GlanceState.enabled(entry.modelData.widget)
                down: area.pressed
            }
            Text {
                x: PlatinumTokens.menuTextLeft
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, (keyText.visible ? keyText.x - PlatinumTokens.menuGap : parent.width - frame.rightInset) - x)
                elide: Text.ElideRight
                text: entry.modelData.label
                color: entry.selected ? PlatinumTokens.highlightText : entry.modelData.enabled ? PlatinumTokens.menuText : PlatinumTokens.menuTextOff
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumText
                font.letterSpacing: PlatinumTokens.platinumTracking
            }
            Text {
                id: keyText
                visible: entry.modelData.key !== ""
                anchors.right: parent.right
                anchors.rightMargin: frame.rightInset
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.key
                color: entry.selected ? PlatinumTokens.highlightText : PlatinumTokens.menuTextSecondary
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
                font.letterSpacing: PlatinumTokens.platinumTracking
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                enabled: entry.modelData.enabled
                onEntered: frame.current = entry.index
                onClicked: frame.run(entry.index, line)
            }
        }
    }

    Repeater {
        id: rows
        model: frame.entries
        Entry {}
    }

    PlatinumMenuParts.Hint {
        rightInset: frame.rightInset
        text: "↑↓ select · Return choose · Esc close"
    }
}
