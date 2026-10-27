pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick

// One level of a Win98 menu: the window bevel, 3 u of face, an optional
// side band, and the rows. Win98Menu builds the cascade out of these; use
// it directly only for a menu that never cascades.
//
// Rows (from the mock's CSS): 18 u (32 u when big); a 20-u icon column
// (32 u when big, with 24-u icons), 3 u (6 u) to the text, 14 u after the
// text, the shortcut at least 12 u after that, a 10-u column for the
// submenu arrow, and 6 u to the edge. Separators are 8 u: an etched line
// 3 u from each neighbour, 2 u in from the sides. Every label starts on one
// edge; shortcuts end on one edge, before the arrow column, as the mock's
// flex rows put them; every arrow ends on one edge. The width is the
// widest label-and-shortcut pair, not the widest label plus the widest
// shortcut.
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

    readonly property real u: Win98Tokens.unitFor(QsWindow.window)
    readonly property real pad: Win98Tokens.frame * u
    readonly property real band: bandText !== "" ? (Win98Tokens.menuBand + 1) * u : 0
    readonly property real rowH: (big ? Win98Tokens.menuBigItemHeight : Win98Tokens.menuItemHeight) * u
    readonly property real iconCol: (big ? 32 : 20) * u
    readonly property real iconGap: (big ? 6 : 3) * u
    readonly property real leftPad: (big ? 4 : 2) * u
    readonly property bool anySub: items.some(it => it && !it.separator && it.submenu && it.submenu.length > 0)
    readonly property real textW: Win98Tokens.ceilU(Math.max(0, ...items.filter(it => it && !it.separator).map(it => Win98Tokens.textWidth(Win98Tokens.plainText(it.text || ""), !!it.bold, root.u))), root.u)
    readonly property real keyW: Win98Tokens.ceilU(Win98Tokens.widest(items.filter(it => it && it.shortcut).map(it => it.shortcut), false, root.u), root.u)
    // The widest label and its shortcut, with the 12-u gap between them.
    readonly property real pairW: items.reduce((w, it) => it && !it.separator
        ? Math.max(w, Win98Tokens.ceilU(Win98Tokens.textWidth(Win98Tokens.plainText(it.text || ""), !!it.bold, root.u), root.u)
            + (it.shortcut ? 12 * u + Win98Tokens.ceilU(Win98Tokens.textWidth(it.shortcut, false, root.u), root.u) : 0)) : w, 0)
    readonly property real fixedW: 2 * pad + band + leftPad + iconCol + iconGap + 14 * u + 16 * u
    readonly property real pairCol: maxWidth > 0 && widthUnits <= 0
        ? Math.max(40 * u, Math.min(pairW, Math.floor((maxWidth - fixedW) / u) * u)) : pairW
    readonly property real rowWidth: leftPad + iconCol + iconGap + pairCol + 14 * u + 10 * u + 6 * u
    readonly property int count: items.length
    readonly property bool hasSeparators: items.some(it => it && it.separator)
    readonly property real naturalRows: items.reduce((h, it) => h + (it && it.separator ? 8 * u : rowH), 0)
    // Columns when it is taller than maxHeight, but never more than fit
    // across maxWidth (80 u a column at least). A menu that still does not
    // fit scrolls, with Win98's arrow strips at its top and bottom.
    readonly property int maxColumns: maxWidth > 0 ? Math.max(1, Math.floor((maxWidth - 2 * pad - band) / (80 * u))) : 1000
    readonly property int columns: Math.min(maxColumns, maxHeight > 0 && !hasSeparators && naturalRows > maxHeight - 2 * pad
        ? Math.ceil(count / Math.max(1, Math.floor((maxHeight - 2 * pad) / rowH))) : 1)
    readonly property int perColumn: Math.ceil(count / columns)
    readonly property real columnWidth: columns > 1
        ? Math.min(Math.max(150 * u, rowWidth), maxWidth > 0 ? Math.floor((maxWidth - 2 * pad - band) / columns / u) * u : 1e6)
        : (widthUnits > 0 ? widthUnits * u - 2 * pad - band : Math.max(rowWidth, 0))
    readonly property real naturalHeight: 2 * pad + (columns > 1 ? perColumn * rowH : naturalRows)
    readonly property bool scrolls: maxHeight > 0 && naturalHeight > maxHeight + 0.5
    readonly property real arrowH: scrolls ? 10 * u : 0
    // How far the rows have scrolled, in logical px (whole rows of the
    // first column's pitch, so they stay on the grid).
    property real scrollY: 0
    readonly property real scrollMax: Math.max(0, naturalHeight - height + 2 * arrowH)
    function scrollBy(d) { root.scrollY = Math.max(0, Math.min(root.scrollMax, root.scrollY + d)); }
    // Keep row i in view.
    function revealRow(i) {
        if (!root.scrolls || i < 0) return;
        const top = root.rowBase(i) - root.pad, bottom = top + root.rowH;
        const view = root.height - 2 * root.pad - 2 * root.arrowH;
        if (top < root.scrollY) root.scrollY = top;
        else if (bottom > root.scrollY + view) root.scrollY = Math.min(root.scrollMax, bottom - view);
    }
    onHighlightedChanged: revealRow(highlighted)
    // A panel that stops scrolling (its bounds grew) shows its first row.
    onScrollsChanged: if (!scrolls) scrollY = 0
    onScrollMaxChanged: if (scrollY > scrollMax) scrollY = scrollMax

    implicitWidth: widthUnits > 0 ? widthUnits * u : 2 * pad + band + columns * columnWidth
    implicitHeight: scrolls ? Math.floor(maxHeight / u) * u : naturalHeight

    // The top of row i, unscrolled, from the panel's top edge.
    function rowBase(i) {
        if (root.columns > 1) return root.pad + (i % root.perColumn) * root.rowH;
        let y = root.pad;
        for (let j = 0; j < i; j++) y += root.items[j] && root.items[j].separator ? 8 * root.u : root.rowH;
        return y;
    }
    // The top of row i as drawn, from the panel's top edge (submenus align
    // to it).
    function rowY(i) { return root.rowBase(i) + root.arrowH - root.scrollY; }
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
        y: root.roll === "up" ? Win98Tokens.snap(root.height * (1 - root.reveal), root.u) : 0
        width: root.roll === "right" ? Win98Tokens.snap(root.width * root.reveal, root.u) : root.width
        height: root.roll === "up" ? root.height - y : Win98Tokens.snap(root.height * (root.roll === "down" ? root.reveal : 1), root.u)

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

            // Win98's scroll arrows: hold the pointer on one to scroll.
            Repeater {
                model: root.scrolls ? [-1, 1] : []
                Item {
                    id: strip
                    required property int modelData
                    x: root.pad + root.band
                    y: modelData < 0 ? root.pad : root.height - root.pad - root.arrowH
                    width: root.width - 2 * root.pad - root.band
                    height: root.arrowH
                    readonly property bool can: modelData < 0 ? root.scrollY > 0 : root.scrollY < root.scrollMax
                    Win98Icon {
                        name: strip.modelData < 0 ? "arrow-up" : "arrow-down"
                        color: strip.can ? Win98Tokens.text : Win98Tokens.gray
                        x: Win98Tokens.half((strip.width - width) / 2, root.u)
                        y: Win98Tokens.snap((strip.height - height) / 2, root.u)
                    }
                    Timer {
                        id: step
                        interval: 80
                        repeat: true
                        running: hold.containsMouse && strip.can
                        onTriggered: root.scrollBy(strip.modelData * root.rowH)
                    }
                    MouseArea { id: hold; anchors.fill: parent; hoverEnabled: true }
                }
            }

            Item {
                id: rowsView
                y: root.pad + root.arrowH
                width: root.width
                height: root.height - 2 * root.pad - 2 * root.arrowH
                clip: root.scrolls
                WheelHandler {
                    enabled: root.scrolls
                    onWheel: event => root.scrollBy((event.angleDelta.y > 0 ? -1 : 1) * root.rowH)
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
                    y: root.rowBase(index) - root.pad - root.scrollY
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
                        // An app's own icon from the icon theme (a web app's
                        // lettermark), when the item has no Win98 icon;
                        // the document icon when the theme lacks it.
                        readonly property string themeSource: row.separator || row.modelData.icon || !row.modelData.themeIcon ? ""
                            : Quickshell.iconPath(row.modelData.themeIcon, true)
                        IconImage {
                            visible: iconCell.themeSource !== ""
                            source: iconCell.themeSource
                            implicitSize: (root.big ? 24 : 16) * root.u
                            x: Win98Tokens.snap((iconCell.width - width) / 2, root.u)
                            y: Win98Tokens.snap((iconCell.height - height) / 2, root.u)
                        }
                        Win98Icon {
                            id: rowIcon
                            readonly property string want: row.separator ? "" : (row.modelData.icon
                                || (row.modelData.themeIcon !== undefined && iconCell.themeSource === "" ? "doc" : ""))
                            visible: want !== ""
                            name: want
                            // A large icon in a small row (a narrow Start) draws at 16 u.
                            size: !root.big && rowIcon.natural[0] > 16 ? 16 : 0
                            // A grey item's glyph is grey too (Restore on a normal window).
                            color: row.usable || row.on ? row.ink : Win98Tokens.gray
                            x: Win98Tokens.snap((iconCell.width - width) / 2, root.u)
                            y: Win98Tokens.snap((iconCell.height - height) / 2, root.u)
                        }
                        Win98Icon {
                            visible: !row.separator && !row.modelData.icon && !row.modelData.themeIcon && row.modelData.checked === true
                            // A radio item (one of a group) draws the dot.
                            name: !row.separator && row.modelData.radio === true ? "dot" : "check"
                            color: row.usable ? row.ink : Win98Tokens.gray
                            x: Win98Tokens.snap((iconCell.width - width) / 2, root.u)
                            y: Win98Tokens.snap((iconCell.height - height) / 2, root.u)
                        }
                    }
                    // Shortcuts end 16 u from the row's right edge.
                    readonly property real keyRight: row.width - 16 * root.u
                    readonly property real keyWidth: !row.separator && row.modelData.shortcut
                        ? Win98Tokens.ceilU(Win98Tokens.textWidth(row.modelData.shortcut, false, root.u), root.u) : 0
                    Win98Text {
                        visible: !row.separator
                        x: root.leftPad + root.iconCol + root.iconGap
                        y: Win98Tokens.snap((row.height - height) / 2, root.u)
                        width: Math.max(0, Math.min(implicitWidth, row.keyRight - (row.keyWidth > 0 ? row.keyWidth + 12 * root.u : 0) - 14 * root.u - x))
                        text: row.separator ? "" : (row.modelData.text || "")
                        // The default item (a double-click runs it) is bold.
                        bold: !row.separator && row.modelData.bold === true
                        color: row.usable ? row.ink : Win98Tokens.gray
                        disabledLook: !row.usable && !row.on
                    }
                    Win98Text {
                        visible: !row.separator && !!row.modelData.shortcut
                        x: row.keyRight - row.keyWidth
                        y: Win98Tokens.snap((row.height - height) / 2, root.u)
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
                        y: Win98Tokens.snap((row.height - height) / 2, root.u)
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
}
