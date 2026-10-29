import Hensou as Kit
import Quickshell
import QtQuick

// A status light. Shape says the status, colour says the tone, so it still
// reads without colour:
//   up       a lit bead
//   down     a bead with a bar across it
//   paused   a bead with two bars
//   pending  a hollow ring
// ChicagoFLF has no ● or ○, so the light is an SVG drawn at device size.
Item {
    id: root

    property string shape: "up"
    property string tone: "normal"
    property real size: 12

    implicitWidth: size
    implicitHeight: size

    readonly property var colors: PlatinumGlanceTokens.lamp[tone === "quiet" ? "normal" : tone]
        || PlatinumGlanceTokens.lamp.muted
    readonly property real dpr: QsWindow.window && QsWindow.window.devicePixelRatio > 0
        ? QsWindow.window.devicePixelRatio : Kit.PlatinumTokens.ratioFor(QsWindow.window)

    readonly property string svg: {
        const b = colors[0], hi = colors[1], lo = colors[2];
        let body;
        if (shape === "pending") {
            body = '<circle cx="6" cy="6" r="4.6" fill="none" stroke="' + lo + '" stroke-width="1.4"/>';
        } else {
            body = '<defs><radialGradient id="g" cx=".38" cy=".32" r=".75"><stop offset="0" stop-color="' + hi
                + '"/><stop offset=".45" stop-color="' + b + '"/><stop offset="1" stop-color="' + lo + '"/></radialGradient></defs>'
                + '<circle cx="6" cy="6" r="5.25" fill="url(#g)" stroke="#000" stroke-width="1"/>';
            if (shape === "up") body += '<circle cx="4.4" cy="4" r="1.1" fill="#fff"/>';
            else if (shape === "down") body += '<rect x="3" y="5.25" width="6" height="1.5" fill="#fff"/>';
            else if (shape === "paused") body += '<rect x="3.75" y="3.5" width="1.5" height="5" fill="#fff"/><rect x="6.75" y="3.5" width="1.5" height="5" fill="#fff"/>';
        }
        return '<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12">' + body + '</svg>';
    }

    Image {
        anchors.fill: parent
        smooth: true
        sourceSize.width: Math.ceil(root.width * root.dpr)
        sourceSize.height: Math.ceil(root.height * root.dpr)
        source: "data:image/svg+xml;utf8," + encodeURIComponent(root.svg)
    }
}
