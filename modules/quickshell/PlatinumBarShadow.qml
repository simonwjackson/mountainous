import Quickshell
import Quickshell.Wayland
import QtQuick

// The short shadow that the light and grey Platinum bars cast on what
// lies under them: PlatinumTokens.barShadowHeight logical px, from 25%
// black to clear.
//
// It is a window of its own, directly under the bar, because the bar's
// window must not grow: a taller bar would reserve more space or draw
// over its own exclusive zone. This window reserves no space
// (ExclusionMode.Ignore), and its empty mask passes every pointer event
// to the window below, so a click on the shadow lands on that window.
//
// The window maps and unmaps with its bar only (chrome off, or an
// inactive Desktop, hides both). The theme switches only what it paints:
// the black bar casts nothing. Remapping on a theme change would stack
// the shadow above a menu that is open at that moment, such as the clock
// menu that holds the Extra dark check box.
PanelWindow {
    id: root

    // The PlatinumTopBar this shadow belongs to.
    required property var bar
    readonly property bool painted: PlatinumTokens.barRaised

    screen: bar.screen
    visible: bar.visible
    anchors { top: true; left: true; right: true }
    margins.top: PlatinumTokens.barHeight
    implicitHeight: PlatinumTokens.barShadowHeight
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "mountainous-bar-shadow"
    mask: Region { width: 0; height: 0 }

    Rectangle {
        visible: root.painted
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: PlatinumTokens.barShadowTop }
            GradientStop { position: 1; color: "#00000000" }
        }
    }
}
