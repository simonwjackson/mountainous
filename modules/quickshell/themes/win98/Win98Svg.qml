import QtQuick

// An SVG drawn at exactly one source pixel per physical pixel. Qt loads an
// SVG at sourceSize and draws it unfiltered over the item, so the item must
// be a whole number of physical pixels (whole or half units) and sit on
// them; then patterns, dots and 1-u edges stay exact.
//
// svg: markup with a viewBox in units. Win98Dither, Win98FocusRect, the
// check box, the radio button and the trackbar thumb draw through this.
Image {
    id: root

    property string svg: ""

    smooth: false
    mipmap: false
    cache: false
    asynchronous: false
    sourceSize.width: Math.max(1, Math.round(width * Win98Tokens.pixelRatio))
    sourceSize.height: Math.max(1, Math.round(height * Win98Tokens.pixelRatio))
    source: svg === "" || width <= 0 || height <= 0 ? ""
        : "data:image/svg+xml;utf8," + encodeURIComponent(svg)
}
