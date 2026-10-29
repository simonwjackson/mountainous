import Hensou as Kit
import Quickshell
import Quickshell.Wayland
import QtQuick
import "bar-plan.js" as BarPlan

// What hangs under the top bar for a moment without being a menu:
//
//   the tag      after a volume or brightness change, the icon, a level
//                well and the number under the control (under » when the
//                control overflowed), for 1.5 s;
//   the balloon  Balloon Help (Mac OS 8): the full value of the title the
//                pointer rests on, in a white balloon with its tail on
//                the title.
//
// A window of its own under the bar, like the bar's shadow: the bar's
// window must not grow. It reserves no space, and its empty mask passes
// every pointer event to the window below. It maps only while it shows
// something. Positions come from bar-plan.js (tagPlan, balloonPlan), so
// both stay inside the screen at every width.
PanelWindow {
    id: root

    // The PlatinumTopBar this belongs to.
    required property var bar

    readonly property bool tagShown: bar.tagId !== "" && tagPlan.show
    readonly property bool balloonShown: !tagShown && bar.balloonId !== "" && bar.balloonText !== ""

    screen: bar.screen
    visible: bar.visible && (tagShown || balloonShown)
    anchors { top: true; left: true; right: true }
    margins.top: Kit.PlatinumTokens.barHeight
    implicitHeight: Math.max(tag.y + tag.height, balloon.y + balloon.height) + 2 * Kit.PlatinumTokens.hairFor(QsWindow.window)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "mountainous-bar-help"
    mask: Region { width: 0; height: 0 }

    readonly property real hair: Kit.PlatinumTokens.hairFor(QsWindow.window)

    // ---------------------------------------------------------- the tag
    readonly property bool tagVol: bar.tagId === "vol"
    readonly property real numberW: Kit.PlatinumMetrics.widest(["100", Kit.PlatinumMetrics.digits(2)])
    readonly property var tagAnchor: bar.tagId !== "" ? bar.controlRect(bar.tagId) : null
    readonly property var tagPlan: tagAnchor ? BarPlan.tagPlan(bar.width, tagAnchor.x, tagAnchor.w, numberW)
        : ({show: false, x: 0, width: 0, well: 0})
    readonly property int tagValue: tagVol ? (bar.sound.muted ? 0 : bar.volLevel) : bar.briLevel

    Item {
        id: tag
        visible: root.tagShown
        x: root.tagPlan.x
        y: 4
        width: root.tagPlan.width
        height: 26

        // The menus' hard shadow, one rule down and right.
        Rectangle {
            x: root.hair
            y: root.hair
            width: parent.width
            height: parent.height
            color: Kit.PlatinumTokens.menuShadow
        }
        PlatinumBevel {
            anchors.fill: parent
            color: Kit.PlatinumTokens.menuSurface
        }

        Row {
            x: BarPlan.TAG.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.tagPlan.well > 0 ? BarPlan.TAG.gap : BarPlan.TAG.slimGap

            Item {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                PlatinumIcon {
                    anchors.fill: parent
                    name: root.tagVol ? root.bar.volIcon : root.bar.briIcon
                    color: Kit.PlatinumTokens.menuText
                    knock: Kit.PlatinumTokens.menuSurface
                }
                PlatinumIcon {
                    visible: root.tagVol && root.bar.sound.muted
                    anchors.fill: parent
                    name: "slash"
                    color: Kit.PlatinumTokens.menuText
                    knock: Kit.PlatinumTokens.menuSurface
                }
            }

            // The level well: sunken, filled in the highlight.
            Rectangle {
                visible: root.tagPlan.well > 0
                anchors.verticalCenter: parent.verticalCenter
                width: root.tagPlan.well
                height: 10
                color: Kit.PlatinumTokens.well

                Rectangle { width: parent.width; height: root.hair; color: Kit.PlatinumTokens.bevelDark }
                Rectangle { width: root.hair; height: parent.height; color: Kit.PlatinumTokens.bevelDark }
                Rectangle { y: parent.height - root.hair; width: parent.width; height: root.hair; color: Kit.PlatinumTokens.bevelLight }
                Rectangle { x: parent.width - root.hair; width: root.hair; height: parent.height; color: Kit.PlatinumTokens.bevelLight }
                Rectangle {
                    x: root.hair
                    y: root.hair
                    height: parent.height - 2 * root.hair
                    width: Kit.PlatinumTokens.snapFor(QsWindow.window, (parent.width - 2 * root.hair) * root.tagValue / 100)
                    color: Kit.PlatinumTokens.highlight
                }
            }

            PlatinumBarNumber {
                anchors.verticalCenter: parent.verticalCenter
                widest: ["100", Kit.PlatinumMetrics.digits(2)]
                text: root.tagVol && root.bar.sound.muted ? "--" : String(root.tagValue)
                tone: Kit.PlatinumTokens.menuText
            }
        }
    }

    // ---------------------------------------------------------- the balloon
    readonly property var balloonAnchor: bar.balloonId !== "" ? bar.controlRect(bar.balloonId) : null
    readonly property var balloonPlan: balloonAnchor ? BarPlan.balloonPlan(bar.width, balloonAnchor.x, balloonAnchor.w,
            Kit.PlatinumMetrics.smallWidth(bar.balloonText) + 24 + 2)
        : ({x: 0, width: 0, tail: 0})

    Item {
        id: balloon
        visible: root.balloonShown
        x: root.balloonPlan.x
        y: 12
        width: root.balloonPlan.width
        height: balloonText.implicitHeight + 16

        Rectangle {
            x: root.hair * 2
            y: root.hair * 2
            width: parent.width
            height: parent.height
            radius: 10
            color: Kit.PlatinumTokens.menuShadow
        }
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Kit.PlatinumTokens.balloon
            border.width: root.hair
            border.color: Kit.PlatinumTokens.menuEdge
        }
        // The tail, up to the title: a wedge that leans left.
        Canvas {
            id: tail
            x: root.balloonPlan.tail - 8
            y: -12 + root.hair
            width: 16
            height: 12
            property color fill: Kit.PlatinumTokens.balloon
            property color edge: Kit.PlatinumTokens.menuEdge
            property real line: root.hair
            onFillChanged: requestPaint()
            onEdgeChanged: requestPaint()
            onLineChanged: requestPaint()
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.beginPath();
                c.moveTo(0, height);
                c.lineTo(width * 0.3, 0);
                c.lineTo(width, height);
                c.closePath();
                c.fillStyle = fill;
                c.fill();
                c.beginPath();
                c.moveTo(0, height);
                c.lineTo(width * 0.3, 0);
                c.lineTo(width, height);
                c.lineWidth = line;
                c.strokeStyle = edge;
                c.stroke();
            }
        }

        Text {
            id: balloonText
            x: 12
            y: 8
            width: parent.width - 24
            text: root.bar.balloonText
            wrapMode: Text.Wrap
            lineHeight: 1.3
            textFormat: Text.PlainText
            color: Kit.PlatinumTokens.menuText
            font.family: Kit.PlatinumTokens.platinumFont
            font.pixelSize: Kit.PlatinumTokens.platinumSmall
            font.letterSpacing: Kit.PlatinumTokens.platinumTracking
        }
    }
}
