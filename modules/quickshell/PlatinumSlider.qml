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
    property real rightInset: PlatinumTokens.menuRightInset
    readonly property bool dragging: area.pressed
    signal moved(real ratio)
    signal released

    readonly property real valueWidth: PlatinumMetrics.widest(["100%", "--"])

    Layout.fillWidth: true
    implicitHeight: 32

    PlatinumIcon {
        visible: root.icon !== ""
        x: PlatinumTokens.menuGutter + (PlatinumTokens.menuGutterWidth - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: 14
        color: PlatinumTokens.menuText
    }

    Item {
        id: track
        x: PlatinumTokens.menuTextLeft
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - PlatinumTokens.menuTextLeft - root.rightInset - root.valueWidth - PlatinumTokens.menuGap
        height: 10

        PlatinumBevel {
            anchors.fill: parent
            sunken: true
            edged: false
            color: PlatinumTokens.well
        }

        Rectangle {
            x: PlatinumTokens.hair
            y: PlatinumTokens.hair
            height: parent.height - 2 * PlatinumTokens.hair
            width: Math.max(0, (parent.width - 2 * PlatinumTokens.hair) * Math.min(1, Math.max(0, root.ratio)))
            color: root.dimmed ? PlatinumTokens.menuTextOff : PlatinumTokens.highlight
        }

        PlatinumBevel {
            id: thumb
            visible: root.hasValue
            width: 12
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(parent.width * Math.min(1, Math.max(0, root.ratio)) - width / 2)
            color: root.dragging ? PlatinumTokens.well : PlatinumTokens.raised

            PlatinumIcon {
                anchors.centerIn: parent
                name: "grip"
                width: 6
                height: 4
                color: PlatinumTokens.bevelDark
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
        color: root.dimmed ? PlatinumTokens.menuTextOff : PlatinumTokens.menuText
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumText
        font.letterSpacing: PlatinumTokens.platinumTracking
    }
}
