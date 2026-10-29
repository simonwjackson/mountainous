import Quickshell
import Hensou as Kit
import QtQuick
import QtQuick.Layouts

// A Platinum slider on the menu grid. The gutter holds its icon, the
// track starts on the text edge, and the value ends on the right edge in a
// box sized for "100%", so the track never moves as the value changes.
//
// A drag across the whole track is the whole range, whatever its width.
Item {
    id: root

    property real ratio: 0          // 0..1 where the thumb sits
    property string valueText: ""
    property string icon: ""
    property bool dimmed: false     // muted: the fill goes grey
    property bool hasValue: true
    property real rightInset: Kit.PlatinumTokens.menuRightInset
    readonly property bool dragging: area.pressed
    signal moved(real ratio)
    signal released

    // The value's box: wide enough for its widest value, so the track
    // never moves. A slider with other values ("48 px") passes its own.
    property real valueWidth: Kit.PlatinumMetrics.widest(["100%", "--"])
    // The track's place in the slider, for a scale drawn under it.
    readonly property real trackX: track.x
    readonly property real trackWidth: track.width

    Layout.fillWidth: true
    implicitHeight: 32

    PlatinumIcon {
        visible: root.icon !== ""
        x: Kit.PlatinumTokens.menuGutter + (Kit.PlatinumTokens.menuGutterWidth - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: 14
        color: Kit.PlatinumTokens.menuText
    }

    Item {
        id: track
        x: Kit.PlatinumTokens.menuTextLeft
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - Kit.PlatinumTokens.menuTextLeft - root.rightInset - root.valueWidth - Kit.PlatinumTokens.menuGap
        height: 10

        PlatinumBevel {
            anchors.fill: parent
            sunken: true
            edged: false
            color: Kit.PlatinumTokens.well
        }

        Rectangle {
            x: Kit.PlatinumTokens.hairFor(QsWindow.window)
            y: Kit.PlatinumTokens.hairFor(QsWindow.window)
            height: parent.height - 2 * Kit.PlatinumTokens.hairFor(QsWindow.window)
            width: Math.max(0, (parent.width - 2 * Kit.PlatinumTokens.hairFor(QsWindow.window)) * Math.min(1, Math.max(0, root.ratio)))
            color: root.dimmed ? Kit.PlatinumTokens.menuTextOff : Kit.PlatinumTokens.highlight
        }

        PlatinumBevel {
            id: thumb
            visible: root.hasValue
            width: 12
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(parent.width * Math.min(1, Math.max(0, root.ratio)) - width / 2)
            color: root.dragging ? Kit.PlatinumTokens.well : Kit.PlatinumTokens.raised

            PlatinumIcon {
                anchors.centerIn: parent
                name: "grip"
                width: 6
                height: 4
                color: Kit.PlatinumTokens.bevelDark
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            anchors.topMargin: -11
            anchors.bottomMargin: -11
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            enabled: root.enabled && root.hasValue
            preventStealing: true

            function emit(x) {
                root.moved(Math.min(1, Math.max(0, (x - 6) / track.width)));
            }

            onPressed: function (mouse) { emit(mouse.x); }
            onPositionChanged: function (mouse) { if (pressed) emit(mouse.x); }
            onReleased: root.released()
            onCanceled: root.released()
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: root.rightInset
        anchors.verticalCenter: parent.verticalCenter
        width: root.valueWidth
        horizontalAlignment: Text.AlignRight
        text: root.valueText
        color: root.dimmed ? Kit.PlatinumTokens.menuTextOff : Kit.PlatinumTokens.menuText
        font.family: Kit.PlatinumTokens.platinumFont
        font.pixelSize: Kit.PlatinumTokens.platinumText
        font.letterSpacing: Kit.PlatinumTokens.platinumTracking
    }
}
