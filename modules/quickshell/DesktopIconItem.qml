import Hensou as Kit
import Quickshell
import QtQuick
import QtQuick.Effects
import "desktop-icons-model.js" as Model
import "lettermark.js" as Mark

// One desktop icon as each OS drew it. The parent (DesktopIcons.qml) does
// all input; this item only draws and reports its image and label rects.
//
// Platinum (Mac OS 8): a 32 px icon, the name on one line in a white box
// (black on white, inverse when selected), the icon darkened when
// selected; an alias's name in italics.
// Memphis (Windows 98): a 32 u icon (whole device pixels, nearest
// neighbour), the name in white under it, wrapped to two lines (all lines
// when selected), selected in the selection colour with the icon dithered
// toward it and a dotted focus rectangle on the focused one; a shortcut
// gets Chicago95's arrow overlay.
Item {
    id: root

    required property var icon
    property string themeId: "platinum"
    property bool selected: false
    property bool focused: false
    // The surface has the keyboard (the focus rectangle shows only then).
    property bool keyboard: false
    property bool dropTarget: false
    property bool dragging: false
    property bool renaming: false
    property real cellWidth: 80
    property real devicePixelRatio: QsWindow.window && QsWindow.window.devicePixelRatio > 0
        ? QsWindow.window.devicePixelRatio : 1.5

    readonly property bool win98: root.themeId === "win98"
    readonly property real u: 2 / root.devicePixelRatio
    readonly property real iconSize: root.win98 ? 32 * root.u : 32
    readonly property bool lit: root.selected || root.dropTarget
    readonly property var art: Model.artFor(root.themeId, root.icon, Mark.needs)
    readonly property string aliasStyle: Model.aliasStyle(root.themeId, root.icon)
    readonly property bool available: root.icon.available !== false

    // The image and the label, in this item's coordinates.
    readonly property rect imageRect: Qt.rect(picture.x, picture.y, picture.width, picture.height)
    readonly property rect labelRect: Qt.rect(label.x, label.y, label.width, label.height)

    width: root.cellWidth
    height: label.y + label.height
    opacity: root.dragging ? 0.55 : 1

    Item {
        id: picture
        x: Math.round((root.width - width) / 2 * root.devicePixelRatio) / root.devicePixelRatio
        y: root.win98 ? 2 * root.u : 2
        width: root.iconSize
        height: root.iconSize
        opacity: root.available ? 1 : 0.45

        Item {
            id: source
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Image {
                anchors.fill: parent
                visible: root.art.type !== "lettermark"
                // Memphis draws the 32 px art at 2 device px per pixel,
                // unfiltered; Platinum lets Qt pick the closest size.
                sourceSize.width: root.win98 ? 32 : Math.round(root.iconSize * root.devicePixelRatio)
                sourceSize.height: root.win98 ? 32 : Math.round(root.iconSize * root.devicePixelRatio)
                smooth: !root.win98
                mipmap: false
                fillMode: Image.PreserveAspectFit
                source: root.art.type === "icon" ? Quickshell.iconPath(root.art.name, "hensou-kind-document")
                    : root.art.type === "file" ? "file://" + root.art.path : ""
            }
            Lettermark {
                visible: root.art.type === "lettermark"
                anchors.fill: parent
                size: root.iconSize
                themeId: root.themeId
                label: root.icon.label || ""
                appId: root.icon.id || ""
                letter: root.art.letter || ""
                tint: root.art.tint || ""
                devicePixelRatio: root.devicePixelRatio
            }
            // Memphis: the shortcut arrow, bottom left, over the icon.
            Image {
                visible: root.aliasStyle === "arrow"
                x: 0
                y: parent.height - height
                width: 16 * root.u
                height: 16 * root.u
                sourceSize.width: 16
                sourceSize.height: 16
                smooth: false
                source: root.aliasStyle === "arrow" ? Quickshell.iconPath("emblem-symbolic-link", true) : ""
            }
        }
        // Selected: Platinum darkens the icon; Memphis tints it toward the
        // selection colour (its 50 % dither, without the pattern's moiré).
        MultiEffect {
            anchors.fill: parent
            source: source
            colorization: root.lit ? 0.5 : 0
            colorizationColor: root.win98 ? Kit.Win98Tokens.selection : "#000000"
        }
    }

    // ---- the label
    readonly property string labelText: root.icon.label || ""

    Item {
        id: label
        visible: !root.renaming
        readonly property real maxWidth: root.win98 ? Math.max(root.cellWidth - 2 * root.u, 74 * root.u)
            : Math.max(root.cellWidth + 32, 112)
        readonly property real padX: root.win98 ? root.u : 3
        width: Math.min(maxWidth, (root.win98 ? w98.implicitWidth : platinumText.implicitWidth) + 2 * padX)
        height: root.win98 ? w98.height + 2 * root.u : platinumText.implicitHeight + 2
        x: Math.round((root.width - width) / 2 * root.devicePixelRatio) / root.devicePixelRatio
        y: picture.y + picture.height + (root.win98 ? 3 * root.u : 3)

        Rectangle {
            anchors.fill: parent
            visible: !root.win98 || root.lit
            color: root.win98 ? Kit.Win98Tokens.selection
                : root.lit ? Kit.PlatinumTokens.menuText : Kit.PlatinumTokens.field
        }
        Text {
            id: platinumText
            visible: !root.win98
            x: label.padX
            y: 1
            width: label.width - 2 * label.padX
            text: root.labelText
            elide: Text.ElideMiddle
            color: root.lit ? Kit.PlatinumTokens.field : Kit.PlatinumTokens.menuText
            font.family: Kit.PlatinumTokens.platinumFont
            font.pixelSize: Kit.PlatinumTokens.platinumSmall
            font.italic: root.aliasStyle === "italic"
            font.letterSpacing: Kit.PlatinumTokens.platinumTracking
            horizontalAlignment: Text.AlignHCenter
            opacity: root.available ? 1 : 0.6
        }
        Win98Text {
            id: w98
            visible: root.win98
            x: label.padX
            y: root.u
            width: label.width - 2 * label.padX
            text: root.labelText
            accessMarks: false
            wrap: true
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            maximumLineCount: root.selected && root.focused ? 1000 : 2
            horizontalAlignment: Text.AlignHCenter
            color: root.lit ? Kit.Win98Tokens.selectionText : "#ffffff"
            disabledLook: !root.available
        }
        Win98FocusRect {
            visible: root.win98 && root.focused && root.keyboard
            anchors.fill: parent
            color: root.lit ? "#ffffff" : "#000000"
        }
    }
}
