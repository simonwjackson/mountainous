import QtQuick
import QtQuick.Layouts

// The » menu: what a narrow bar could not hold, by name, with what each
// would have shown. A control opens its own menu, hung from ». Failed
// dictation's Retry and Dismiss run from here. Nothing leaves the bar
// without landing here.
//
// The name column is reserved at its longest name; a value gets what is
// left and elides on the right edge. The control's own menu always has
// the full value.
PlatinumMenuFrame {
    id: frame

    required property var bar

    preferredWidth: 260
    showHeader: false
    scrolls: false

    readonly property var labels: ({
        bt: "Bluetooth", wifi: "Wi-Fi", vol: "Sound", bri: "Brightness",
        oci: "OCI egress", disk: "Server storage", builder: "Remote builds", ntf: "Notifications",
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
    readonly property real nameWidth: {
        let w = 0;
        for (const id of frame.entries)
            if (id !== "status") w = Math.max(w, PlatinumMetrics.width(frame.labels[id] || id));
        return w;
    }

    function run(id) {
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

    Repeater {
        model: frame.entries

        PlatinumMenuListRow {
            id: row
            required property string modelData
            Layout.fillWidth: true
            Layout.preferredHeight: PlatinumTokens.menuLine + 4
            rowHeight: PlatinumTokens.menuLine + 4
            rightInset: frame.rightInset
            readonly property bool action: modelData === "retry" || modelData === "dismiss"
            readonly property bool status: modelData === "status"
            selected: hover.hovered && !status
            mark: action || status ? "" : frame.bar.iconFor(modelData)
            name: status ? frame.bar.dictationText : frame.labels[modelData] || modelData
            nameColor: status ? PlatinumTokens.menuDanger : PlatinumTokens.menuText
            onClicked: if (!status) frame.run(modelData)

            HoverHandler { id: hover }

            Text {
                readonly property real room: row.width - PlatinumTokens.menuTextLeft - row.rightInset
                    - PlatinumTokens.menuGap - frame.nameWidth
                width: Math.max(0, Math.min(implicitWidth, room))
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: row.action || row.status ? "" : frame.bar.valueFor(row.modelData)
                color: row.fg2
                font.family: PlatinumTokens.platinumFont
                font.pixelSize: PlatinumTokens.platinumSmall
                font.letterSpacing: PlatinumTokens.platinumTracking
            }
        }
    }
}
