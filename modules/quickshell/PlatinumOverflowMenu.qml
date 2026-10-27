pragma ComponentBehavior: Bound

import QtQuick

// The » menu: what a narrow bar could not hold, by name, with what each
// would have shown. A control opens its own menu, hung from ». Failed
// dictation's Retry and Dismiss run from here. Nothing leaves the bar
// without landing here.
//
// The name column is reserved at its longest name; a value gets what is
// left and elides on the right edge. The control's own menu always has
// the full value. A warning value keeps its tone, and each control's
// Super+O letter stands on the right edge.
PlatinumMenuFrame {
    id: frame

    required property var bar

    preferredWidth: 260
    showHeader: false
    scrolls: entriesList.scrolls

    readonly property var labels: ({
        bt: "Bluetooth", wifi: "Wi-Fi", vol: "Sound", bri: "Brightness",
        oci: "OCI egress", disk: "Server storage", fleet: "Fleet", builder: "Remote builds", ntf: "Notifications",
        apple: "Apple menu", battery: "Battery", clock: "Clock", app: "Applications",
        retry: "Retry dictation", dismiss: "Dismiss"
    })

    // One row per control, and Retry (only when it can) and Dismiss for
    // dictation.
    readonly property var entries: {
        const out = [];
        for (const id of frame.bar.plan.overflow) {
            if (id === "dictation") {
                // What failed, said in full, above its Retry and Dismiss:
                // the bar may have given those words up.
                out.push("status");
                if (frame.bar.dictation.canRetry) out.push("retry");
                out.push("dismiss");
            } else {
                out.push(id);
            }
        }
        return out;
    }
    // Each control's Super+O letter, on the right edge, as in the mock.
    readonly property var keys: ({ bt: "B", wifi: "W", vol: "S", bri: "L", oci: "C", disk: "D", fleet: "F", builder: "R", ntf: "N" })
    readonly property real keyWidth: PlatinumMetrics.smallWidest(["B", "W", "S", "L", "C", "D", "F", "R", "N"])
    readonly property bool anyKey: frame.entries.some(function (id) { return frame.keys[id] !== undefined; })
    // A value in a warning or danger tone keeps that tone here, as on the bar.
    function valueColor(id) {
        const t = typeof frame.bar.toneOf === "function" ? frame.bar.toneOf(id) : "normal";
        return t === "danger" || t === "warning" ? PlatinumTokens.menuTone(t) : PlatinumTokens.menuTextSecondary;
    }
    readonly property real nameWidth: {
        let w = 0;
        for (const id of frame.entries)
            if (id !== "status") w = Math.max(w, PlatinumMetrics.width(frame.labels[id] || id));
        return w;
    }

    function run(id) {
        if (id === "battery" || id === "status") return;
        if (id === "retry") {
            MenuState.close();
            frame.bar.dictation.retryFailed();
        } else if (id === "dismiss") {
            MenuState.close();
            frame.bar.dictation.dismissFailure();
        } else {
            MenuState.open(id, frame.bar.modelData, frame.bar.anchorFor(id));
        }
    }

    PlatinumMenuList {
        id: entriesList
        model: frame.entries
        currentIndex: -1
        Component.onCompleted: view.forceActiveFocus()
        Keys.onUpPressed: moveSelection(-1)
        Keys.onDownPressed: moveSelection(1)
        Keys.onReturnPressed: if (currentIndex >= 0) frame.run(frame.entries[currentIndex])
        Keys.onEnterPressed: if (currentIndex >= 0) frame.run(frame.entries[currentIndex])

        delegate: PlatinumMenuListRow {
            id: row
            required property string modelData
            width: ListView.view.width
            rowHeight: PlatinumTokens.menuLine + 4
            rightInset: frame.rightInset
            readonly property bool action: modelData === "retry" || modelData === "dismiss"
            readonly property bool status: modelData === "status"
            readonly property bool readout: status || modelData === "battery"
            selected: (hover.hovered || ListView.isCurrentItem) && !readout
            mark: action || status ? "" : frame.bar.iconFor(modelData)
            name: status ? frame.bar.dictationText : frame.labels[modelData] || modelData
            nameColor: status ? PlatinumTokens.menuDanger : PlatinumTokens.menuText
            onClicked: if (!readout) frame.run(modelData)

            HoverHandler { id: hover }

            Text {
                readonly property real room: row.width - PlatinumTokens.menuTextLeft - row.rightInset
                    - PlatinumTokens.menuGap - frame.nameWidth
                    - (frame.anyKey && !row.status && !row.action ? frame.keyWidth + PlatinumTokens.menuGap : 0)
                width: Math.max(0, Math.min(implicitWidth, room))
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: row.action || row.status ? "" : frame.bar.valueFor(row.modelData)
                color: row.selected ? row.fg2 : frame.valueColor(row.modelData)
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
                font.letterSpacing: PlatinumTokens.platinumTracking
            }

            Text {
                visible: frame.anyKey && !row.status && !row.action
                width: frame.keyWidth
                horizontalAlignment: Text.AlignRight
                text: frame.keys[row.modelData] || ""
                color: row.fg2
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
                font.letterSpacing: PlatinumTokens.platinumTracking
            }
        }
    }
}
