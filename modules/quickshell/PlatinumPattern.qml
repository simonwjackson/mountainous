import Hensou as Kit
import Quickshell
import QtQuick

// A 1-bit checker on exact device pixels: ink on alternate cells, ground
// (or nothing) on the rest. The SVG is drawn at one source pixel per device
// pixel and shown unfiltered (the Windows 98 theme's technique), so at scale 1.5 a cell of 3
// device pixels is 3 device pixels, never a blend. The item must sit on
// whole device pixels; the glance space and the progress bars do.
//
// originX, originY: the item's offset from the screen's origin in device
// pixels, so the checker keeps the screen's phase wherever it is drawn.
Image {
    id: root

    property int cell: 1
    property color ink: "#000000"
    property color ground: "transparent"
    property int originX: 0
    property int originY: 0
    // A size to draw at before the window has one (the glance space is
    // drawn at startup, while hidden, so the first summon does no work).
    property real drawWidth: width
    property real drawHeight: height

    readonly property real dpr: QsWindow.window && QsWindow.window.devicePixelRatio > 0
        ? QsWindow.window.devicePixelRatio : (QsWindow.window && QsWindow.window.devicePixelRatio > 0 ? QsWindow.window.devicePixelRatio : 1.5)
    readonly property int pw: Math.max(1, Math.round(drawWidth * dpr))
    readonly property int ph: Math.max(1, Math.round(drawHeight * dpr))
    readonly property int period: 2 * Math.max(1, cell)

    function hex(c) {
        if (c.a === 0) return "none";
        const h = function (v) { const s = Math.round(v * 255).toString(16); return s.length < 2 ? "0" + s : s; };
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    smooth: false
    mipmap: false
    cache: false
    asynchronous: false
    fillMode: Image.Stretch
    sourceSize.width: pw
    sourceSize.height: ph
    source: drawWidth <= 0 || drawHeight <= 0 ? "" : "data:image/svg+xml;utf8," + encodeURIComponent(
        '<svg xmlns="http://www.w3.org/2000/svg" width="' + pw + '" height="' + ph
        + '" viewBox="0 0 ' + pw + ' ' + ph + '" shape-rendering="crispEdges">'
        + '<defs><pattern id="c" width="' + period + '" height="' + period + '" patternUnits="userSpaceOnUse"'
        + ' x="' + (-((root.originX % period) + period) % period) + '" y="' + (-((root.originY % period) + period) % period) + '">'
        + '<rect x="0" y="0" width="' + cell + '" height="' + cell + '" fill="' + hex(ink) + '"/>'
        + '<rect x="' + cell + '" y="' + cell + '" width="' + cell + '" height="' + cell + '" fill="' + hex(ink) + '"/>'
        + '</pattern></defs>'
        + (root.ground.a > 0 ? '<rect width="' + pw + '" height="' + ph + '" fill="' + hex(ground) + '"/>' : '')
        + '<rect width="' + pw + '" height="' + ph + '" fill="url(#c)"/></svg>')
}
