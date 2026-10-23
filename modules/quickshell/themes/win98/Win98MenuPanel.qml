pragma ComponentBehavior: Bound

import QtQuick

// One level of a Win98 menu: the window bevel, 3 u of face, an optional
// side band, and the rows. Win98Menu builds the cascade out of these; use
// it directly only for a menu that never cascades.
//
// Rows (from the mock's CSS): 18 u (32 u when big); a 20-u icon column
// (32 u when big, with 24-u icons), 3 u (6 u) to the text, 14 u after the
// text, a shortcut column 12 u after that, a 10-u column for the submenu
// arrow, and 6 u to the edge. Separators are 8 u: an etched line 3 u from
// each neighbour, 2 u in from the sides. Every label starts on one edge,
// every shortcut starts on one edge and every arrow ends on one edge.
//
// A menu taller than maxHeight runs into more columns, as Win98's did
// (only when it has no separators).
Item {
    id: root

    property var items: []
    property bool big: false
    property string bandText: ""
    property string bandSubText: ""
    property real widthUnits: 0        // fixed outer width; 0 = measured
    property int highlighted: -1
    property real maxHeight: 0         // logical px; 0 = no limit
    // The widest the panel may be (logical px; 0 = no limit). Labels
    // longer than the room elide with three dots; shortcuts keep their
    // column.
    property real maxWidth: 0
    // Roll-out: "none", "up" (from the bottom edge), "down" or "right".
    property string roll: "none"

    signal hovered(int index)
    signal clicked(int index)

    readonly property real u: Win98Tokens.u
    readonly property real pad: Win98Tokens.frame * u
    readonly property real band: bandText !== "" ? (Win98Tokens.menuBand + 1) * u : 0
    readonly property real rowH: (big ? Win98Tokens.menuBigItemHeight : Win98Tokens.menuItemHeight) * u
    readonly property real iconCol: (big ? 32 : 20) * u
    readonly property real iconGap: (big ? 6 : 3) * u
    readonly property real leftPad: (big ? 4 : 2) * u
    readonly property bool anySub: items.some(it => it && !it.separator && it.submenu && it.submenu.length > 0)
    readonly property real textW: Win98Tokens.ceilU(Win98Tokens.widest(items.filter(it => it && !it.separator).map(it => Win98Tokens.plainText(it.text || "")), false))
    readonly property real keyW: Win98Tokens.ceilU(Win98Tokens.widest(items.filter(it => it && it.shortcut).map(it => it.shortcut), false))
    readonly property real fixedW: 2 * pad + band + leftPad + iconCol + iconGap + 14 * u + (keyW > 0 ? 12 * u + keyW : 0) + 16 * u
    readonly property real textCol: maxWidth > 0 && widthUnits <= 0
        ? Math.max(40 * u, Math.min(textW, Math.floor((maxWidth - fixedW) / u) * u)) : textW
    // Where the shortcut column starts, from the row's left edge.
    readonly property real keyX: leftPad + iconCol + iconGap + textCol + 14 * u + (keyW > 0 ? 12 * u : 0)
    readonly property real rowWidth: keyX + keyW + 10 * u + 6 * u
    readonly property int count: items.length
    readonly property bool hasSeparators: items.some(it => it && it.separator)
    readonly property real naturalRows: items.reduce((h, it) => h + (it && it.separator ? 8 * u : rowH), 0)
    readonly property int columns: maxHeight > 0 && !hasSeparators && naturalRows > maxHeight - 2 * pad
        ? Math.ceil(count / Math.max(1, Math.floor((maxHeight - 2 * pad) / rowH))) : 1
    readonly property int perColumn: Math.ceil(count / columns)
    readonly property real columnWidth: columns > 1 ? Math.max(150 * u, rowWidth) : (widthUnits > 0 ? width - 2 * pad - band : Math.max(rowWidth, 0))

    implicitWidth: widthUnits > 0 ? widthUnits * u : 2 * pad + band + columns * columnWidth
    implicitHeight: 2 * pad + (columns > 1 ? perColumn * rowH : naturalRows)

    // The top of row i, from the panel's top edge (submenus align to it).
    function rowY(i) {
        if (root.columns > 1) return root.pad + (i % root.perColumn) * root.rowH;
        let y = root.pad;
        for (let j = 0; j < i; j++) y += root.items[j] && root.items[j].separator ? 8 * root.u : root.rowH;
        return y;
    }
    function rowX(i) { return root.pad + root.band + (root.columns > 1 ? Math.floor(i / root.perColumn) * root.columnWidth : 0); }

    property real reveal: roll === "none" || Win98Tokens.rollDuration === 0 ? 1 : 0
    NumberAnimation on reveal {
        running: root.roll !== "none" && Win98Tokens.rollDuration > 0
        from: 0; to: 1
        duration: Win98Tokens.rollDuration
        easing.type: Easing.Linear
    }

    Item {
        id: clipper
        clip: root.reveal < 1
        x: 0
        y: root.roll === "up" ? Win98Tokens.snap(root.height * (1 - root.reveal)) : 0
        width: root.roll === "right" ? Win98Tokens.snap(root.width * root.reveal) : root.width
        height: root.roll === "up" ? root.height - y : root.roll === "down" ? Win98Tokens.snap(root.height * root.reveal) : root.height

        Item {
            id: content
            y: -clipper.y
            width: root.width
            height: root.height

            Win98Bevel {
                anchors.fill: parent
                variant: "window"
            }

            // The side band: W95FA at twice its size, so it stays on the grid.
            Rectangle {
                visible: root.bandText !== ""
                x: root.pad; y: root.pad
                width: Win98Tokens.menuBand * root.u
                height: root.height - 2 * root.pad
                clip: true
                gradient: Gradient {
                    GradientStop { position: 0; color: Win98Tokens.caption2 }
                    GradientStop { position: 1; color: Win98Tokens.caption1 }
                }
                Row {
                    // Rotated a quarter turn, reading upwards from 6 u above the
                    // bottom. The size-2 text draws through unfiltered layers,
                    // and a quarter turn maps whole pixels onto whole pixels.
                    transformOrigin: Item.TopLeft
                    rotation: -90
                    x: 0
                    y: parent.height - 6 * root.u
                    Win98Text { text: root.bandText; accessMarks: false; size: 2; bold: true; color: "#ffffff" }
                    Win98Text { text: " " + root.bandSubText; accessMarks: false; size: 2; color: "#c0c0c0"; visible: root.bandSubText !== "" }
                }
            }

            Repeater {
                model: root.items

                Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool separator: !!(modelData && modelData.separator)
                    readonly property bool on: !separator && index === root.highlighted
                    readonly property bool usable: !separator && modelData.enabled !== false
                    readonly property bool sub: !separator && !!modelData.submenu && modelData.submenu.length > 0
                    readonly property color ink: on ? Win98Tokens.selectionText : Win98Tokens.text
                    x: root.rowX(index)
                    y: root.rowY(index)
                    width: root.columnWidth
                    height: separator ? 8 * root.u : root.rowH

                    Win98Separator {
                        visible: row.separator
                        width: row.width
                    }

                    Rectangle {
                        visible: row.on
                        anchors.fill: parent
                        color: Win98Tokens.selection
                    }

                    Item {
                        id: iconCell
                        visible: !row.separator
                        x: root.leftPad
                        width: root.iconCol
                        height: row.height
                        Win98Icon {
                            visible: !row.separator && !!row.modelData.icon
                            name: row.separator ? "" : (row.modelData.icon || "")
                            color: row.ink
                            x: Win98Tokens.snap((iconCell.width - width) / 2)
                            y: Win98Tokens.snap((iconCell.height - height) / 2)
                        }
                        Win98Icon {
                            visible: !row.separator && !row.modelData.icon && row.modelData.checked === true
                            name: "check"
                            color: row.usable ? row.ink : Win98Tokens.gray
                            x: Win98Tokens.snap((iconCell.width - width) / 2)
                            y: Win98Tokens.snap((iconCell.height - height) / 2)
                        }
                    }
                    Win98Text {
                        visible: !row.separator
                        x: root.leftPad + root.iconCol + root.iconGap
                        y: Win98Tokens.snap((row.height - height) / 2)
                        width: Math.min(implicitWidth, root.keyX - 14 * root.u - x)
                        text: row.separator ? "" : (row.modelData.text || "")
                        color: row.usable ? row.ink : Win98Tokens.gray
                        disabledLook: !row.usable && !row.on
                    }
                    Win98Text {
                        visible: !row.separator && !!row.modelData.shortcut
                        x: root.keyX
                        y: Win98Tokens.snap((row.height - height) / 2)
                        text: row.separator ? "" : (row.modelData.shortcut || "")
                        accessMarks: false
                        color: row.usable ? row.ink : Win98Tokens.gray
                        disabledLook: !row.usable && !row.on
                    }
                    Win98Icon {
                        visible: row.sub
                        name: "arrow-right"
                        color: row.usable ? row.ink : Win98Tokens.gray
                        x: row.width - 6 * root.u - width
                        y: Win98Tokens.snap((row.height - height) / 2)
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !row.separator
                        hoverEnabled: true
                        onEntered: root.hovered(row.index)
                        onClicked: root.clicked(row.index)
                    }
                }
            }
        }
    }
}
