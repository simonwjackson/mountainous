import QtQuick

// Win98's 50% dither: every other unit in color, the rest transparent, so
// the face shows through. Scroll-bar tracks and latched buttons use it.
// phase 0 colours the units where x + y is odd (the mock's CSS); 1 the even.
Win98Svg {
    id: root

    property color color: Win98Tokens.dither
    property int phase: 0

    readonly property int cols: Math.max(1, Math.round(width / root.u))
    readonly property int rows: Math.max(1, Math.round(height / root.u))

    svg: '<svg xmlns="http://www.w3.org/2000/svg" width="' + cols + '" height="' + rows
        + '" viewBox="0 0 ' + cols + ' ' + rows + '" shape-rendering="crispEdges">'
        + '<defs><pattern id="d" width="2" height="2" patternUnits="userSpaceOnUse">'
        + (phase === 0 ? '<rect x="1" y="0" width="1" height="1" fill="' + color + '"/><rect x="0" y="1" width="1" height="1" fill="' + color + '"/>'
                       : '<rect x="0" y="0" width="1" height="1" fill="' + color + '"/><rect x="1" y="1" width="1" height="1" fill="' + color + '"/>')
        + '</pattern></defs><rect width="' + cols + '" height="' + rows + '" fill="url(#d)"/></svg>'
}
