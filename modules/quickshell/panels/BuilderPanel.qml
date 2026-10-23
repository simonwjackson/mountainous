import Quickshell
import QtQuick
import "../builder-gate.js" as Gate

// Shared remote-builder actions and keyboard focus. Theme views receive this
// state owner; they never own the builder command or its pending state.
Scope {
    id: root

    required property var gate
    property bool shown: false
    // True when SUPER+O R opened the menu: the focus ring shows at once.
    property bool openedByKeyboard: false
    property bool keyboardUsed: false
    // The action the keyboard is on.
    property string focusId: "toggle"

    readonly property var actionList: Gate.actions(gate.sample, gate.pending)

    onShownChanged: {
        if (!shown) return;
        root.keyboardUsed = root.openedByKeyboard;
        root.focusId = Gate.moveFocus(root.actionList, "", 1);
        root.gate.refresh();
    }

    // When the focused action turns disabled (it just ran, or its reason
    // went away), the focus moves to the first one still enabled.
    onActionListChanged: {
        if (root.gate.pending !== "") return;
        const target = root.actionList.filter(function (t) { return t.id === root.focusId; })[0];
        if (!target || !target.enabled) root.focusId = Gate.moveFocus(root.actionList, "", 1);
    }

    function action(id) {
        for (const a of root.actionList) if (a.id === id) return a;
        return null;
    }

    function activate(id) {
        const a = root.action(id);
        if (a && a.enabled) root.gate.run(a.command);
    }

    function byKey(id) {
        root.keyboardUsed = true;
        root.focusId = id;
        root.activate(id);
    }

    function moveFocus(delta) {
        root.keyboardUsed = true;
        root.focusId = Gate.moveFocus(root.actionList, root.focusId, delta);
    }


}
