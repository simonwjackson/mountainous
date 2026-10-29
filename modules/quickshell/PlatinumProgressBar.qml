import Quickshell
import Hensou as Kit
import QtQuick

// A Mac OS 8 progress bar as a readout: a black hair frame, a sunken empty
// part and a fill with a light top line. The fill takes the value's tone.
// An untrusted value (a host that is down) gets a grey fill under the
// Platinum disabled stipple, so it reads as stale without hiding it.
Item {
    id: root

    property real value: 0          // percent; null or NaN draws empty
    property string tone: "normal"
    property bool stale: false
    property bool selected: false

    implicitWidth: 56
    implicitHeight: 9

    readonly property real h: Kit.PlatinumTokens.hairFor(QsWindow.window)
    readonly property real fraction: typeof value === "number" && isFinite(value) ? Math.max(0, Math.min(100, value)) / 100 : 0
    readonly property color fill: stale || !(typeof value === "number" && isFinite(value)) ? Kit.PlatinumTokens.menuTextOff
        : tone === "danger" ? PlatinumGlanceTokens.barDanger
        : tone === "warning" ? PlatinumGlanceTokens.barWarning : PlatinumGlanceTokens.barFill
    readonly property color fillHi: stale ? Kit.PlatinumTokens.menuTextOff
        : tone === "danger" ? PlatinumGlanceTokens.barDangerHi
        : tone === "warning" ? PlatinumGlanceTokens.barWarningHi : PlatinumGlanceTokens.barFillHi

    Rectangle {
        anchors.fill: parent
        color: PlatinumGlanceTokens.barEmpty
        border.width: root.h
        border.color: root.selected ? Kit.PlatinumTokens.highlightText : Kit.PlatinumTokens.menuEdge
    }
    // The sunken empty part's shade.
    Rectangle { x: root.h; y: root.h; width: parent.width - 2 * root.h; height: root.h; color: Kit.PlatinumTokens.bevelDark }
    Rectangle { x: root.h; y: root.h; width: root.h; height: parent.height - 2 * root.h; color: Kit.PlatinumTokens.bevelDark }

    Item {
        id: fillBox
        x: root.h
        y: root.h
        height: parent.height - 2 * root.h
        width: Math.round((parent.width - 2 * root.h) * root.fraction / root.h) * root.h
        clip: true

        Rectangle { anchors.fill: parent; color: root.fill }
        Rectangle { width: parent.width; height: root.h; color: root.fillHi }
        PlatinumPattern {
            visible: root.stale && parent.width > 0
            anchors.fill: parent
            cell: 1
            ink: PlatinumGlanceTokens.barEmpty
        }
    }
}
