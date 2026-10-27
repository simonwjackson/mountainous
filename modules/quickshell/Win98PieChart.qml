import QtQuick

// The drive pie from a Win98 disk's Properties: a tilted disc, used in
// blue and free in magenta, with its side showing below (the mock's
// pie98). 42 x 27 u. stale draws it grey (the host is not up, so the value
// is from before).
Win98Svg {
    id: root

    property real percent: 0       // 0..100
    property bool stale: false

    width: 42 * u
    height: 27 * u

    svg: {
        const p = Math.max(0, Math.min(100, isNaN(root.percent) ? 0 : root.percent));
        const rx = 20, ry = 10, cx = 21, cy = 11, dep = 4, a = p / 100 * 2 * Math.PI;
        const ex = cx + rx * Math.sin(a), ey = cy - ry * Math.cos(a), large = a > Math.PI ? 1 : 0;
        const T = Win98Tokens;
        const U = String(root.stale ? T.gray : T.pieUsed), US = String(root.stale ? T.sh : T.pieUsedSide);
        const F = String(root.stale ? T.face : T.pieFree), FS = String(root.stale ? T.sh : T.pieFreeSide);
        const used = p >= 100 ? '<ellipse cx="' + cx + '" cy="' + cy + '" rx="' + rx + '" ry="' + ry + '" fill="' + U + '"/>'
            : p <= 0 ? "" : '<path d="M' + cx + ' ' + cy + ' L' + cx + ' ' + (cy - ry) + ' A' + rx + ' ' + ry + ' 0 ' + large + ' 1 '
                + ex.toFixed(2) + ' ' + ey.toFixed(2) + ' Z" fill="' + U + '"/>';
        let side = "";
        if (p > 25) {
            const a2 = Math.min(a, 1.5 * Math.PI), x2 = cx + rx * Math.sin(a2), y2 = cy - ry * Math.cos(a2);
            side = '<path d="M' + (cx + rx) + ' ' + cy + ' A' + rx + ' ' + ry + ' 0 0 1 ' + x2.toFixed(2) + ' ' + y2.toFixed(2)
                + ' V' + (y2 + dep).toFixed(2) + ' A' + rx + ' ' + ry + ' 0 0 0 ' + (cx + rx) + ' ' + (cy + dep) + ' Z" fill="' + US + '"/>';
        }
        return '<svg xmlns="http://www.w3.org/2000/svg" width="42" height="27" viewBox="0 0 42 27">'
            + '<path d="M' + (cx - rx) + ' ' + cy + ' A' + rx + ' ' + ry + ' 0 0 0 ' + (cx + rx) + ' ' + cy + ' V' + (cy + dep)
            + ' A' + rx + ' ' + ry + ' 0 0 1 ' + (cx - rx) + ' ' + (cy + dep) + ' Z" fill="' + FS + '" stroke="#000" stroke-width=".8"/>'
            + side + '<ellipse cx="' + cx + '" cy="' + cy + '" rx="' + rx + '" ry="' + ry + '" fill="' + F + '"/>' + used
            + '<ellipse cx="' + cx + '" cy="' + cy + '" rx="' + rx + '" ry="' + ry + '" fill="none" stroke="#000" stroke-width=".8"/></svg>';
    }
}
