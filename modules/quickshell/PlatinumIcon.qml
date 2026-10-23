import QtQuick

// One SVG mark from icons/, in one colour. The image is rasterised at the
// screen's physical size, so edges stay sharp at scale 1.5.
Item {
    id: root

    property string name: ""
    property color color: PlatinumTokens.menuText
    // The colour behind the mark, for the strokes that cut into it (the
    // cloud's arrow, the charging bolt, a slash).
    property color knock: "transparent"
    property real size: 16

    implicitWidth: size
    implicitHeight: size

    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: true
        sourceSize.width: Math.ceil(root.width * PlatinumTokens.pixelRatio)
        sourceSize.height: Math.ceil(root.height * PlatinumTokens.pixelRatio)
        source: root.name === "" ? "" : PlatinumIconStore.url(root.name, root.color, root.knock)
    }
}
