pragma Singleton

import Quickshell
import QtQuick

// Platinum's disabled stipple: a checker with one physical pixel per cell.
// Qt's SVG renderer has no <pattern>, so the checker is one path of unit
// squares, built once per size and colour.
Singleton {
    id: root

    // Filled in place, without a change signal, so a binding that asks for
    // a checker never depends on the cache it fills.
    readonly property var cache: ({})

    function url(size, color) {
        const key = size + "/" + String(color);
        if (root.cache[key]) return root.cache[key];
        let d = "";
        for (let y = 0; y < size; y++)
            for (let x = (y % 2); x < size; x += 2) d += "M" + x + " " + y + "h1v1h-1z";
        const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + size + '" height="' + size
            + '" viewBox="0 0 ' + size + ' ' + size + '" shape-rendering="crispEdges"><path fill="'
            + String(color) + '" d="' + d + '"/></svg>';
        const value = "data:image/svg+xml;utf8," + encodeURIComponent(svg);
        root.cache[key] = value;
        return value;
    }
}
