pragma ComponentBehavior: Bound

import QtQuick
import "oci-model.js" as OciModel

// OCI egress as a Win98 list view in report mode: a column header and one
// row per profile (used, projected, this month's share of the quota). Five
// rows show; more scroll. A window narrower than the columns scrolls them
// sideways, as Win98's list views did. The shared OciEgress owns the data.
Win98Window {
    id: root

    required property var panel

    title: "OCI egress \u00b7 this month"
    iconName: "oci-normal"
    onCloseClicked: MenuState.close()

    // The columns, in units: Profile, Used GB, Projected GB, This month.
    readonly property real contentUnits: 392
    readonly property real innerWidth: list.width - 4 * u - (vbar.visible ? 18 * u : 0)
    // Narrower than its 420 u (a narrow screen): the columns keep their
    // widths and scroll sideways. Otherwise the last column takes the rest.
    readonly property bool narrow: width < 420 * u - 0.5
    readonly property real tableWidth: narrow ? Math.max(innerWidth, contentUnits * u) : innerWidth
    // A short screen: rows go first (down to two), then the status bar;
    // the body scrolls only after that.
    // Measured after layout settles, not bound: the list's height feeds
    // the window's own height, so a binding would loop. The sum is a fixed
    // point (what the list gives up, it adds back).
    property real natural: 0
    Timer {
        id: naturalMeasure
        interval: 0
        onTriggered: root.measureNatural()
    }
    function measureNatural() { root.natural = implicitHeight + (5 - visibleRows) * 16 * u + (statusArea.visible ? 0 : 26 * u); }
    Connections {
        target: root
        function onImplicitHeightChanged() { naturalMeasure.restart(); }
    }
    Component.onCompleted: naturalMeasure.restart()
    readonly property real squeeze: availableHeight > 0 ? Math.max(0, natural - availableHeight) : 0
    readonly property int visibleRows: Math.max(2, 5 - Math.ceil(squeeze / (16 * u) - 1e-6))
    readonly property bool dropStatus: squeeze > 3 * 16 * u + 0.5

    Column {
        id: body
        width: root.bodyWidth
        spacing: 6 * root.u

        Win98Text {
            width: parent.width
            wrap: true
            text: root.panel.stateText.replace(/\u2026/g, "...") + ". Quota 10240 GB per profile."
            accessMarks: false
            color: root.panel.state === "error" ? Win98Tokens.warning : Win98Tokens.text
        }

        Win98Bevel {
            id: list
            width: parent.width
            height: (17 + root.visibleRows * 16 + 6 + (root.narrow ? 16 : 0)) * root.u
            variant: "field"
            color: Win98Tokens.win

            Flickable {
                id: table
                x: 2 * root.u; y: 2 * root.u
                width: root.innerWidth
                height: (17 + root.visibleRows * 16 + 2) * root.u
                clip: true
                interactive: false
                contentWidth: root.tableWidth
                contentHeight: height

                Column {
                    width: root.tableWidth
                    Row {
                        Header { width: 96 * root.u; text: "Profile" }
                        Header { width: 88 * root.u; text: "Used GB"; alignRight: true }
                        Header { width: 104 * root.u; text: "Projected GB"; alignRight: true }
                        Header { width: root.tableWidth - 288 * root.u; text: "This month"; alignRight: true }
                    }
                    Flickable {
                        id: rowsView
                        width: root.tableWidth
                        height: (root.visibleRows * 16 + 2) * root.u
                        clip: true
                        interactive: false
                        contentHeight: rowsColumn.height
                        Column {
                            id: rowsColumn
                            width: root.tableWidth
                            Repeater {
                                model: root.panel.rows
                                Rectangle {
                                    id: r
                                    required property var modelData
                                    required property int index
                                    readonly property var rule: OciModel.rowRule(modelData)
                                    readonly property bool selected: index === 0
                                    readonly property color ink: selected ? Win98Tokens.selectionText : Win98Tokens.winText
                                    width: root.tableWidth
                                    height: 16 * root.u
                                    color: selected ? Win98Tokens.selection : "transparent"
                                    Cell { x: 3 * root.u; width: 93 * root.u; text: r.modelData.name; color: r.ink }
                                    Cell { x: 96 * root.u; width: 88 * root.u; text: r.modelData.used; alignRight: true; color: r.ink }
                                    Cell { x: 184 * root.u; width: 104 * root.u; text: r.modelData.projected; alignRight: true; color: r.ink }
                                    Cell {
                                        x: 288 * root.u
                                        width: r.width - 288 * root.u - 5 * root.u
                                        text: r.rule.value
                                        alignRight: true
                                        color: r.selected ? r.ink : r.rule.tone === "danger" ? Win98Tokens.danger
                                            : r.rule.tone === "warning" ? Win98Tokens.warning : Win98Tokens.winText
                                    }
                                }
                            }
                            Item {
                                visible: root.panel.rows.length === 0
                                width: root.tableWidth
                                height: 16 * root.u
                                Cell {
                                    x: 3 * root.u
                                    width: parent.width
                                    text: root.panel.state === "loading" ? "Loading..." : "No profiles"
                                    color: Win98Tokens.gray
                                }
                            }
                        }
                    }
                }
            }
            Win98ScrollBar {
                id: vbar
                visible: root.panel.rows.length > root.visibleRows
                x: list.width - 2 * root.u - width
                y: 2 * root.u
                height: (17 + root.visibleRows * 16 + 2) * root.u
                flickable: rowsView
                step: 16 * root.u
            }
            Win98ScrollBar {
                visible: root.narrow
                orientation: Qt.Horizontal
                x: 2 * root.u
                y: list.height - 2 * root.u - height
                width: list.width - 4 * root.u
                flickable: table
                step: 16 * root.u
            }
        }

        Item {
            id: statusArea
            visible: !root.dropStatus
            width: parent.width
            height: 20 * root.u
            Win98StatusBar {
                y: 2 * root.u
                width: parent.width
                panes: ["Esc or click outside to close"]
            }
        }
    }

    component Header: Item {
        id: h
        property string text: ""
        property bool alignRight: false
        height: 17 * root.u
        Win98Bevel { anchors.fill: parent; variant: "button" }
        Win98Text {
            x: h.alignRight ? h.width - 4 * root.u - width : 4 * root.u
            y: 2 * root.u
            width: Math.min(implicitWidth, h.width - 8 * root.u)
            text: h.text
            accessMarks: false
        }
    }
    component Cell: Item {
        id: c
        property string text: ""
        property bool alignRight: false
        property color color: Win98Tokens.winText
        height: 16 * root.u
        Win98Text {
            x: c.alignRight ? c.width - width : 0
            y: Win98Tokens.snap((c.height - height) / 2, root.u)
            width: Math.min(implicitWidth, c.width)
            text: c.text
            accessMarks: false
            color: c.color
        }
    }
}
