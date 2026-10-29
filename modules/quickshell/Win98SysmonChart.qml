import Hensou as Kit
import QtQuick

// System Monitor's chart, for the Fleet Properties sheet: a white sunken
// well, a dotted grid at the quarters both ways, and the series as a 1-u
// line (the mock's chart98). max: the top of the scale; 0 takes the
// series' own largest value. stale draws the line grey (the host is not
// up, so the values are from before). The labels ("now", "1 h ago",
// "max") belong to the caller.
Win98Bevel {
    id: root

    property var values: []
    property real max: 100
    property color lineColor: Kit.Win98Tokens.chartCpu
    property bool stale: false

    variant: "field"
    color: Kit.Win98Tokens.win
    implicitWidth: 120 * u
    implicitHeight: 30 * u

    readonly property int iw: Math.max(1, Math.round(width / u) - 4)
    readonly property int ih: Math.max(1, Math.round(height / u) - 4)
    readonly property real scaleTop: root.max > 0 ? root.max : Math.max(0.0001, Math.max.apply(null, (root.values || []).concat([0])))

    function dotted(horizontal, at, length) {
        let out = "";
        for (let i = 0; i < length; i += 2) out += horizontal
            ? '<rect x="' + i + '" y="' + at + '" width="1" height="1"/>' : '<rect x="' + at + '" y="' + i + '" width="1" height="1"/>';
        return out;
    }

    Win98Svg {
        x: 2 * root.u
        y: 2 * root.u
        width: root.iw * root.u
        height: root.ih * root.u
        svg: {
            const iw = root.iw, ih = root.ih, v = root.values || [];
            let grid = "";
            for (const f of [0.25, 0.5, 0.75]) grid += root.dotted(true, Math.round(ih * f), iw) + root.dotted(false, Math.round(iw * f), ih);
            let d = "";
            for (let i = 0; i < v.length; i++) {
                const x = v.length > 1 ? i / (v.length - 1) * (iw - 1) : 0;
                const y = (1 - Math.min(v[i], root.scaleTop) / root.scaleTop) * (ih - 1);
                d += (i ? " L" : "M") + (x + 0.5).toFixed(2) + " " + (y + 0.5).toFixed(2);
            }
            const ink = root.stale ? String(Kit.Win98Tokens.gray) : String(root.lineColor);
            return '<svg xmlns="http://www.w3.org/2000/svg" width="' + iw + '" height="' + ih + '" viewBox="0 0 ' + iw + ' ' + ih + '">'
                + '<g fill="' + String(Kit.Win98Tokens.chartGrid) + '" shape-rendering="crispEdges">' + grid + '</g>'
                + (v.length > 1 ? '<path d="' + d + '" fill="none" stroke="' + ink + '" stroke-width="1"/>' : '')
                + '</svg>';
        }
    }
}
