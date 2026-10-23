import QtQuick
import QtQuick.Layouts

// The » menu: the controls a narrow bar could not hold, by name, with
// what each would have shown. Choosing one opens its own menu, hung from
// ». Nothing leaves the bar without landing here.
MenuFrame {
    id: frame

    required property var bar

    preferredWidth: 260
    showHeader: false
    scrolls: false

    readonly property var labels: ({
        bt: "Bluetooth", wifi: "Wi-Fi", vol: "Sound", bri: "Brightness",
        oci: "OCI egress", disk: "Server storage", ntf: "Notifications"
    })

    Repeater {
        model: frame.bar.plan.overflow

        MenuListRow {
            id: row
            required property string modelData
            required property int index
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.menuLine + 4
            rowHeight: Theme.menuLine + 4
            selected: hover.hovered
            mark: frame.bar.iconFor(modelData)
            name: frame.labels[modelData] || modelData
            onClicked: MenuState.open(modelData, frame.bar.modelData, frame.bar.anchorFor(modelData))

            HoverHandler { id: hover }

            Text {
                text: frame.bar.valueFor(row.modelData)
                color: row.fg2
                font.family: Theme.platinumFont
                font.pixelSize: Theme.platinumSmall
                font.letterSpacing: Theme.platinumTracking
            }
        }
    }
}
