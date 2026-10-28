import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import "app-icon.js" as AppIcon

// An app's icon from the icon theme. Inactive (a window on a page the
// screen is not showing, a hidden app) draws Platinum's disabled look: the
// icon in grey, under a one-physical-pixel checker of the surface colour
// masked to the icon's own shape. It is not an opacity fade.
Item {
    id: root

    // An icon theme name, or "" for none.
    property string name: ""
    property real size: 20
    property bool inactive: false
    // The surface the icon sits on: the checker's colour.
    property color surface: PlatinumTokens.stripSurface

    implicitWidth: size
    implicitHeight: size

    readonly property int physical: Math.max(1, Math.round(size * PlatinumTokens.pixelRatio))

    // The icon is always drawn through the effect, so becoming inactive
    // (a page change) only changes the effect's numbers. Toggling the
    // source's visibility instead left the effect blank.
    IconImage {
        id: image
        anchors.fill: parent
        implicitSize: root.size
        visible: false
        layer.enabled: true
        source: root.name === "" ? "" : Quickshell.iconPath(root.name, AppIcon.fallback(root.name))
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        saturation: root.inactive ? -1 : 0
        contrast: root.inactive ? -0.25 : 0
    }

    // The checker, one physical pixel per cell, drawn at the icon's
    // physical size so no resampling softens it.
    Image {
        id: checker
        anchors.fill: parent
        visible: false
        smooth: false
        sourceSize.width: root.physical
        sourceSize.height: root.physical
        source: PlatinumStipple.url(root.physical, root.surface)
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.inactive
        source: checker
        maskEnabled: true
        maskSource: image
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.0
    }
}
