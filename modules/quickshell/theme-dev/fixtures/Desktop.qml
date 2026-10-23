import Quickshell
import QtQuick
Scope {
    id: root
    required property var screen
    required property var context
    required property var theme
    property bool active: false
    function reveal() { context.revealed = true; }
    function hide() { context.revealed = false; }
    function open(control) { context.control = control; }
    PanelWindow {
        screen: root.screen
        visible: root.active
        anchors { top: true; left: true; right: true }
        implicitHeight: 28
        color: "#dddddd"
    }
}
