import Hensou as Kit
import Quickshell
import QtQuick

// A Memphis option button: a 12-u pixel circle with two rings split on the
// diagonal (grey and white outside, black and light grey inside, as the
// sunken bevel), a white well and a 4-u dot. The label sits 5 u right.
// Focus: a dotted rectangle around the label. The owner keeps the group
// exclusive: set checked from clicked().
FocusScope {
    id: root

    property string text: ""
    property bool checked: false
    property bool showFocus: false
    property bool showPressed: false

    signal clicked

    readonly property real u: Kit.MemphisTokens.unitFor(QsWindow.window)
    readonly property bool pressing: showPressed || (area.pressed && area.containsMouse)

    implicitWidth: Kit.MemphisTokens.radio * u + (text !== "" ? 5 * u + label.implicitWidth : 0)
    implicitHeight: Kit.MemphisTokens.checkBox * u
    activeFocusOnTab: enabled

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }

    // The 12-u circle: o outer ring, i inner ring, w the well.
    readonly property var bitmap: [
        "....oooo....", "..ooiiiioo..", ".oiiwwwwiio.", ".oiwwwwwwio.",
        "oiwwwwwwwwio", "oiwwwwwwwwio", "oiwwwwwwwwio", "oiwwwwwwwwio",
        ".oiwwwwwwio.", ".oiiwwwwiio.", "..ooiiiioo..", "....oooo...."
    ]

    MemphisSvg {
        id: circle
        y: Kit.MemphisTokens.snap((root.height - height) / 2, root.u)
        width: Kit.MemphisTokens.radio * root.u
        height: width
        svg: {
            const T = Kit.MemphisTokens;
            const well = root.enabled && !root.pressing ? T.win : T.face;
            const dot = root.enabled ? T.winText : T.gray;
            let s = '<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" shape-rendering="crispEdges">';
            const px = (x, y, c) => '<rect x="' + x + '" y="' + y + '" width="1" height="1" fill="' + c + '"/>';
            for (let y = 0; y < 12; y++) {
                for (let x = 0; x < 12; x++) {
                    const c = root.bitmap[y][x];
                    // Split on the diagonal: top-left takes the dark side.
                    const topLeft = x + y < 11 || (x + y === 11 && y < x);
                    if (c === "o") s += px(x, y, topLeft ? T.sh : T.hi);
                    else if (c === "i") s += px(x, y, topLeft ? T.dk : T.li);
                    else if (c === "w") s += px(x, y, well);
                }
            }
            if (root.checked)
                s += '<rect x="5" y="4" width="2" height="4" fill="' + dot + '"/><rect x="4" y="5" width="4" height="2" fill="' + dot + '"/>';
            return s + '</svg>';
        }
    }

    MemphisText {
        id: label
        visible: root.text !== ""
        x: circle.width + 5 * root.u
        width: Math.min(implicitWidth, root.width - x)
        text: root.text
        disabledLook: !root.enabled
    }

    MemphisFocusRect {
        visible: root.enabled && root.text !== "" && (root.showFocus || root.activeFocus)
        x: label.x - root.u; y: -root.u
        width: label.width + 2 * root.u
        height: label.height + 2 * root.u
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        onPressed: root.forceActiveFocus()
        onClicked: root.clicked()
    }
}
