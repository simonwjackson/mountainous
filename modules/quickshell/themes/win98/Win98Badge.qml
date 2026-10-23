import QtQuick

// A count badge: white digits in a 3x5 pixel face on red, 7 u tall, with a
// 1-u ring in the face colour that separates it from the icon under it.
// Digits, "+" and "!"; anything else draws as "!".
Item {
    id: root

    property string text: ""
    property color color: Win98Tokens.badge
    property color ringColor: Win98Tokens.face

    readonly property real u: Win98Tokens.u
    readonly property var digits: ({
        "0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
        "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001010010",
        "8": "111101111101111", "9": "111101111001111", "+": "000010111010000", "!": "010010010000010"
    })
    readonly property int textUnits: Math.max(0, text.length * 4 - 1)

    implicitWidth: (textUnits + 2) * u
    implicitHeight: 7 * u

    Rectangle {
        x: -root.u; y: -root.u
        width: root.width + 2 * root.u; height: root.height + 2 * root.u
        color: root.ringColor
    }
    Win98Svg {
        anchors.fill: parent
        svg: {
            let rects = "";
            for (let c = 0; c < root.text.length; c++) {
                const m = root.digits[root.text[c]] || root.digits["!"];
                for (let i = 0; i < 15; i++)
                    if (m[i] === "1") rects += '<rect x="' + (1 + c * 4 + i % 3) + '" y="' + (1 + Math.floor(i / 3)) + '" width="1" height="1"/>';
            }
            const w = root.textUnits + 2;
            return '<svg xmlns="http://www.w3.org/2000/svg" width="' + w + '" height="7" viewBox="0 0 ' + w + ' 7" shape-rendering="crispEdges">'
                + '<rect width="' + w + '" height="7" fill="' + root.color + '"/><g fill="#ffffff">' + rects + '</g></svg>';
        }
    }
}
