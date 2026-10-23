import Quickshell
import QtQuick
import QtQuick.Layouts
import "notification-model.js" as Model

// The notification centre: every open item, as a Platinum menu under the
// bar's bell. This Scope owns the keyboard state; MenuHost shows the menu.
//
// Dismiss all and close stay in the header at every width; the status
// badge is a readout and sits under the title. The list scrolls, and each
// card keeps all of its actions (see NotificationMenuCard).
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

    property Component menu: Component {
        MenuFrame {
            id: frame

            readonly property bool showList: root.view.kind === "ready"
            readonly property bool warnBadge: root.badge.kind === "local_only" || root.badge.kind === "delivery_error"

            preferredWidth: 440
            title: root.view.kind === "ready" ? "Notifications  " + root.service.count : "Notifications"
            detail: root.badge.kind === "none" ? "" : root.badge.text
            detailColor: frame.warnBadge ? Theme.menuWarning : Theme.menuTextSecondary
            scrolls: list.scrolls

            headerTrailing: PlatinumButton {
                text: frame.menuWidth >= 300 ? "Dismiss all" : "All"
                fixedWidth: PlatinumMetrics.buttonWidth(["Dismiss all"])
                enabled: root.view.kind === "ready"
                onClicked: root.service.dismissAll()
            }

            QtObject {
                id: clock
                property double now: Date.now()
            }

            Timer {
                interval: 30000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: clock.now = Date.now()
            }

            // What the badge means, with the daemon's error text in full.
            MenuParts.Line {
                visible: frame.warnBadge
                rightInset: frame.rightInset
                text: visible ? root.badge.detail : ""
                bottomPadding: 6
            }

            // notifyd is down. The countdown is the backoff in
            // Model.socketLost; R or the button skips it.
            CentreMessage {
                visible: root.view.kind === "offline"
                title: "Notifications offline"
                warn: true
                detail: "notifyd is not answering on " + root.service.socketPath
                    + ". Notifications will not show until it is back."
                    + (root.view.kind === "offline" && root.view.retryInSeconds > 0
                        ? " Trying again in " + root.view.retryInSeconds + " s." : "")
                actionText: "Try again now"
                rightInset: frame.rightInset
                onActionClicked: root.service.reconnectNow()
            }

            CentreMessage {
                visible: root.view.kind === "connecting"
                title: "Connecting to notifyd"
                detail: "Waiting for the notification list."
                rightInset: frame.rightInset
            }

            CentreMessage {
                visible: root.view.kind === "empty"
                title: "No notifications"
                detail: "New notifications from this desktop, your other desktops and your agents appear here."
                rightInset: frame.rightInset
            }

            MenuParts.Separator { visible: frame.showList }

            MenuList {
                id: list

                visible: frame.showList
                model: ScriptModel { values: root.service.items }

                readonly property var current: Model.itemAt(root.service.items, currentIndex)

                Component.onCompleted: {
                    view.forceActiveFocus();
                    currentIndex = count > 0 ? 0 : -1;
                    Qt.callLater(list.takeRequest);
                }

                // A popup's "Show all" lands here, on its open card.
                function takeRequest() {
                    const request = root.service.takeFocusRequest();
                    if (request.kind === "none") return;
                    const index = root.service.items.findIndex(function (i) { return i.id === request.value; });
                    if (index < 0) return;
                    currentIndex = index;
                    view.positionViewAtIndex(index, ListView.Beginning);
                }

                // Move among the selected card's actions, and scroll the
                // focused button into view: a card with many actions can
                // be taller than the list.
                function moveAction(delta) {
                    if (list.current.kind === "none") return;
                    root.keyboardUsed = true;
                    root.actionFocus = Model.moveActionFocus(root.actionFocus,
                        list.current.value.actions.length, delta);
                    Qt.callLater(list.revealAction);
                }

                function revealAction() {
                    if (root.actionFocus.kind !== "action") return;
                    const row = view.itemAtIndex(list.currentIndex);
                    const button = row ? row.actionButton(root.actionFocus.index) : null;
                    if (!button) return;
                    const top = button.mapToItem(view.contentItem, 0, 0).y;
                    const margin = 8;
                    if (top - margin < view.contentY) view.contentY = top - margin;
                    else if (top + button.height + margin > view.contentY + view.height)
                        view.contentY = top + button.height + margin - view.height;
                }

                // An open card can be taller than the list. These keys move
                // through it a page at a time.
                function scrollBy(pixels) {
                    const top = view.originY;
                    const bottom = view.originY + Math.max(0, view.contentHeight - view.height);
                    view.contentY = Math.max(top, Math.min(bottom, view.contentY + pixels));
                }

                onCurrentIndexChanged: root.actionFocus = Model.noActionFocus()
                onCountChanged: {
                    if (count > 0 && currentIndex < 0) currentIndex = 0;
                    if (currentIndex >= count) currentIndex = count - 1;
                }
                onVisibleChanged: if (visible) view.forceActiveFocus()

                function move(offset) {
                    if (count === 0) return;
                    root.keyboardUsed = true;
                    currentIndex = Math.max(0, Math.min(count - 1, currentIndex + offset));
                    view.positionViewAtIndex(currentIndex, ListView.Contain);
                }

                function runAction(index) {
                    if (list.current.kind === "none") return;
                    const item = list.current.value;
                    if (index < 0 || index >= item.actions.length) return;
                    root.service.invoke(item.id, item.actions[index].key);
                }

                view.Keys.priority: Keys.BeforeItem
                view.Keys.onPressed: function (event) {
                    const current = list.current;
                    if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        list.move(-1);
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        list.move(1);
                    } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                        root.keyboardUsed = true;
                        if (event.modifiers & Qt.ShiftModifier) root.service.dismissAll();
                        else if (current.kind === "some") root.service.dismiss(current.value.id);
                    } else if (event.key === Qt.Key_Right
                               || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                        list.moveAction(1);
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab
                               || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                        list.moveAction(-1);
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.keyboardUsed = true;
                        if (current.kind === "some") {
                            const action = Model.enterTarget(root.actionFocus, current.value);
                            if (action.kind === "some") list.runAction(action.value.index);
                        }
                    } else if (event.key === Qt.Key_Space || event.key === Qt.Key_E) {
                        root.keyboardUsed = true;
                        if (current.kind === "some") root.service.toggleExpanded(current.value.id);
                    } else if (event.key === Qt.Key_PageDown) {
                        list.scrollBy(view.height * 0.9);
                    } else if (event.key === Qt.Key_PageUp) {
                        list.scrollBy(-view.height * 0.9);
                    } else if (event.key === Qt.Key_Home) {
                        view.contentY = view.originY;
                    } else if (event.key === Qt.Key_End) {
                        list.scrollBy(view.contentHeight);
                    } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        root.keyboardUsed = true;
                        list.runAction(event.key - Qt.Key_1);
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

                delegate: NotificationMenuCard {
                    required property var modelData
                    required property int index

                    item: modelData
                    width: ListView.view.width
                    rightInset: frame.rightInset
                    now: clock.now
                    bodyLines: frame.maxHeight >= 600 ? 6 : 3
                    lastRow: index === list.count - 1
                    expanded: root.service.expandedIds[modelData.id] === true
                    selected: root.keyboardUsed && list.currentIndex === index
                    actionFocus: selected ? root.actionFocus : Model.noActionFocus()

                    onDismissRequested: root.service.dismiss(modelData.id)
                    onActionRequested: function (key) { root.service.invoke(modelData.id, key); }
                    onExpandToggled: root.service.toggleExpanded(modelData.id)
                    onBodyClicked: {
                        list.currentIndex = index;
                        const fallback = Model.defaultAction(modelData);
                        if (fallback.kind === "some" && modelData.sender_alive)
                            root.service.invoke(modelData.id, fallback.value.action.key);
                    }
                }
            }

            MenuParts.Hint {
                visible: frame.showList && frame.maxHeight >= 400
                rightInset: frame.rightInset
                text: "↑↓ select · ←→ or Tab action · 1–9 run · Enter run · Del dismiss · Space more · PgUp PgDn scroll · Esc close"
            }

            Shortcut {
                sequence: "R"
                context: Qt.WindowShortcut
                enabled: root.view.kind === "offline"
                onActivated: root.service.reconnectNow()
            }
        }
    }

    // A whole-menu message for a view with no list.
    component CentreMessage: ColumnLayout {
        id: message
        property string title: ""
        property string detail: ""
        property bool warn: false
        property string actionText: ""
        property real rightInset: Theme.menuRightInset
        signal actionClicked

        Layout.fillWidth: true
        Layout.leftMargin: Theme.menuTextLeft
        Layout.rightMargin: rightInset
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        spacing: 6

        Text {
            Layout.fillWidth: true
            text: message.title
            wrapMode: Text.Wrap
            color: message.warn ? Theme.menuWarning : Theme.menuText
            font.family: Theme.platinumFont
            font.pixelSize: Theme.platinumText
            font.letterSpacing: Theme.platinumTracking
        }

        Text {
            Layout.fillWidth: true
            text: message.detail
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Theme.menuTextSecondary
            font.family: Theme.platinumFont
            font.pixelSize: Theme.platinumSmall
            font.letterSpacing: Theme.platinumTracking
            lineHeight: 1.2
        }

        PlatinumButton {
            visible: message.actionText !== ""
            Layout.topMargin: 4
            text: message.actionText
            isDefault: true
            onClicked: message.actionClicked()
        }
    }
}
