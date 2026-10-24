import QtQuick

// Mac OS 8's indeterminate progress bar, the barber pole: diagonal stripes
// in a sunken frame that move while Beszel is asked. It stops under
// reduced motion (GlanceState.reducedMotion) and still reads as "working".
Item {
    id: root
    implicitHeight: 11
    readonly property real h: PlatinumTokens.hair
    readonly property real tile: 16

    Rectangle {
        anchors.fill: parent
        color: PlatinumGlanceTokens.barFill
        border.width: root.h
        border.color: PlatinumTokens.menuEdge
    }
    Item {
        x: root.h
        y: root.h
        width: parent.width - 2 * root.h
        height: parent.height - 2 * root.h
        clip: true
        Image {
            id: stripes
            width: parent.width + root.tile
            height: parent.height
            fillMode: Image.Tile
            horizontalAlignment: Image.AlignLeft
            verticalAlignment: Image.AlignTop
            smooth: true
            source: "data:image/svg+xml;utf8," + encodeURIComponent(
                '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">'
                + '<rect width="16" height="16" fill="' + PlatinumGlanceTokens.barFill + '"/>'
                + '<path d="M0 16 L8 0 H16 L8 16 Z" fill="' + PlatinumGlanceTokens.barFillHi + '"/></svg>')
            NumberAnimation on x {
                from: -root.tile
                to: 0
                duration: 600
                loops: Animation.Infinite
                running: root.visible && !GlanceState.reducedMotion
            }
        }
    }
}
