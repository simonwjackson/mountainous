import Quickshell
import QtQuick
import "../notification-model.js" as Model

// Shared notification-centre selection, action focus and status. The current
// theme supplies the view and calls the notification service's public methods.
Scope {
    id: root

    required property var service
    property bool shown: false

    property bool keyboardUsed: false
    // Which action on the selected card the keyboard is on. It goes back to
    // none whenever the selection moves.
    property var actionFocus: Model.noActionFocus()

    onShownChanged: if (root.shown) {
        root.keyboardUsed = false;
        root.actionFocus = Model.noActionFocus();
    }

    // One tagged value decides what the menu shows: offline, connecting,
    // empty or ready (Model.viewState). Each block below selects itself.
    readonly property var view: root.service.view
    readonly property var badge: Model.statusBadge(root.view, root.service.status)

}
