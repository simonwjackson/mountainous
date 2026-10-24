import QtQuick
import QtQuick.Shapes

// One metric's last hour, in a sunken Platinum well: a line, and under it a
// flat tint of the same colour (a solid colour, not a translucent fill).
Item {
    id: root

    property var values: []
    property real max: 100          // the top of the well; 0 = the series' own maximum
    property string tone: "normal"

    implicitHeight: 26

    readonly property real h: PlatinumTokens.hair
    readonly property real ceiling: root.max > 0 ? root.max
        : Math.max(0.0001, Math.max.apply(null, (root.values.length ? root.values : [0])))
    readonly property color line: tone === "danger" ? PlatinumGlanceTokens.barDanger
        : tone === "warning" ? PlatinumGlanceTokens.barWarning : PlatinumGlanceTokens.barFill
    readonly property color under: Qt.tint(PlatinumGlanceTokens.barEmpty, Qt.rgba(line.r, line.g, line.b, 0.22))

    Rectangle {
        anchors.fill: parent
        color: PlatinumGlanceTokens.barEmpty
        border.width: root.h
        border.color: PlatinumTokens.menuEdge
    }
    Rectangle { x: root.h; y: root.h; width: parent.width - 2 * root.h; height: root.h; color: PlatinumTokens.bevelDark }
    Rectangle { x: root.h; y: root.h; width: root.h; height: parent.height - 2 * root.h; color: PlatinumTokens.bevelDark }

    Item {
        id: plot
        x: 2 * root.h
        y: 2 * root.h
        width: parent.width - 3 * root.h
        height: parent.height - 3 * root.h
        clip: true
        readonly property var points: {
            const n = root.values.length;
            const out = [];
            for (let i = 0; i < n; i++) {
                const v = Math.max(0, Math.min(root.ceiling, root.values[i]));
                out.push(Qt.point(n === 1 ? plot.width : i / (n - 1) * plot.width,
                    plot.height - 1 - v / root.ceiling * (plot.height - 2)));
            }
            return out;
        }

        Shape {
            anchors.fill: parent
            visible: plot.points.length > 0
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillColor: root.under
                PathPolyline {
                    path: plot.points.length ? [Qt.point(0, plot.height)].concat(plot.points)
                        .concat([Qt.point(plot.width, plot.height)]) : []
                }
            }
            ShapePath {
                strokeWidth: 1.5 * root.h
                strokeColor: root.line
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: plot.points }
            }
        }
    }
}
