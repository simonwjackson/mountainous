pragma ComponentBehavior: Bound

import QtQuick

// A Win98 surface: a fill and up to three 1-u rings of edge lines. Each
// ring has a top-left colour and a bottom-right colour. Where two lines of
// a ring meet at the top-right and bottom-left corners, the bottom-right
// line wins, as Win98 drew it; the etched variants ("group", "channel")
// let the top-left line win instead, as the mock's CSS does.
//
// Variants, outer ring first (hi/li light, sh/dk dark):
//   button          hi/dk, li/sh   push buttons, scroll arrows, caption buttons
//   window          li/dk, hi/sh   window frames, menus, scroll thumbs
//   pressed         dk/hi, sh/li   a pressed button
//   field           sh/hi, dk/li   text fields, lists, check boxes
//   thinSunken      sh/hi          tray well, status-bar panes, flat pressed
//   thinRaised      hi/sh          flat buttons on hover, grips
//   default         dk/dk, hi/dk, li/sh   the default push button
//   defaultPressed  dk/dk, sh/sh  a push button held down
//   group           sh/hi, hi/sh  group-box etch (top-left wins)
//   channel         sh/hi, dk/li  trackbar channel (top-left wins)
//   edge            dk/dk         a 1-u black frame (drop-down list)
//   flatPressed     sh/sh         a scroll arrow held down
//   flat            none
Item {
    id: root

    property string variant: "button"
    // Another appearance's colours (Win98Tokens.palette), for previews.
    property var scheme: null
    property color color: scheme ? scheme.face : Win98Tokens.face
    property bool filled: true

    readonly property real u: Win98Tokens.u
    readonly property var rings: {
        const T = root.scheme || Win98Tokens;
        switch (root.variant) {
        case "window": return [[T.li, T.dk], [T.hi, T.sh]];
        case "pressed": return [[T.dk, T.hi], [T.sh, T.li]];
        case "field": return [[T.sh, T.hi], [T.dk, T.li]];
        case "thinSunken": return [[T.sh, T.hi]];
        case "thinRaised": return [[T.hi, T.sh]];
        case "default": return [[T.dk, T.dk], [T.hi, T.dk], [T.li, T.sh]];
        case "defaultPressed": return [[T.dk, T.dk], [T.sh, T.sh]];
        case "group": return [[T.sh, T.hi], [T.hi, T.sh]];
        case "channel": return [[T.sh, T.hi], [T.dk, T.li]];
        case "edge": return [[T.dk, T.dk]];
        case "flatPressed": return [[T.sh, T.sh]];
        case "flat": return [];
        default: return [[T.hi, T.dk], [T.li, T.sh]];
        }
    }
    readonly property bool topLeftWins: variant === "group" || variant === "channel"
    // The width of the rings: content starts this far in.
    readonly property real inset: rings.length * u

    Rectangle {
        visible: root.filled
        anchors.fill: parent
        anchors.margins: root.inset
        color: root.color
    }

    Repeater {
        model: root.rings.length

        Item {
            id: ring
            required property int index
            readonly property real i: index * root.u
            readonly property color light: root.rings[index][0]
            readonly property color shade: root.rings[index][1]
            readonly property real tl: root.topLeftWins ? 0 : root.u
            readonly property real br: root.topLeftWins ? root.u : 0
            anchors.fill: parent

            // top
            Rectangle {
                x: ring.i; y: ring.i
                width: root.width - 2 * ring.i - ring.tl; height: root.u
                color: ring.light
            }
            // left
            Rectangle {
                x: ring.i; y: ring.i
                width: root.u; height: root.height - 2 * ring.i - ring.tl
                color: ring.light
            }
            // bottom
            Rectangle {
                x: ring.i + ring.br; y: root.height - ring.i - root.u
                width: root.width - 2 * ring.i - ring.br; height: root.u
                color: ring.shade
            }
            // right
            Rectangle {
                x: root.width - ring.i - root.u; y: ring.i + ring.br
                width: root.u; height: root.height - 2 * ring.i - ring.br
                color: ring.shade
            }
        }
    }
}
