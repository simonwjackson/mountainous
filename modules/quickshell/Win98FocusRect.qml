import QtQuick

// The keyboard focus mark: a dotted 1-u rectangle, one unit on, one off.
// Fill the area it should outline; it draws on the area's edge.
Win98Svg {
    id: root

    property color color: Win98Tokens.focus

    readonly property int cols: Math.max(1, Math.round(width / root.u))
    readonly property int rows: Math.max(1, Math.round(height / root.u))

    svg: '<svg xmlns="http://www.w3.org/2000/svg" width="' + cols + '" height="' + rows
        + '" viewBox="0 0 ' + cols + ' ' + rows + '" shape-rendering="crispEdges">'
        + '<defs><pattern id="d" width="2" height="2" patternUnits="userSpaceOnUse">'
        + '<rect x="0" y="0" width="1" height="1" fill="' + color + '"/><rect x="1" y="1" width="1" height="1" fill="' + color + '"/>'
        + '</pattern></defs><g fill="url(#d)">'
        + '<rect width="' + cols + '" height="1"/>'
        + '<rect y="' + (rows - 1) + '" width="' + cols + '" height="1"/>'
        + '<rect width="1" height="' + rows + '"/>'
        + '<rect x="' + (cols - 1) + '" width="1" height="' + rows + '"/>'
        + '</g></svg>'
}
