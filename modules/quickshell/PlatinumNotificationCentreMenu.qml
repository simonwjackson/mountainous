import Quickshell
import QtQuick
import QtQuick.Layouts
import "notification-model.js" as Model


PlatinumMenuFrame {
    id: frame
    required property var panel

    readonly property bool showList: panel.view.kind === "ready"
    readonly property bool warnBadge: panel.badge.kind === "local_only" || panel.badge.kind === "delivery_error"

    preferredWidth: 440
    title: panel.view.kind === "ready" ? "Notifications  " + panel.service.count : "Notifications"
    detail: panel.badge.kind === "none" ? "" : panel.badge.text
    detailColor: frame.warnBadge ? PlatinumTokens.menuWarning : PlatinumTokens.menuTextSecondary
    scrolls: list.scrolls

    headerTrailing: PlatinumButton {
        text: frame.menuWidth >= 300 ? "Dismiss all" : "All"
        fixedWidth: PlatinumMetrics.buttonWidth(["Dismiss all"])
        enabled: panel.view.kind === "ready"
        onClicked: panel.service.dismissAll()
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
    PlatinumMenuParts.Line {
        visible: frame.warnBadge
        rightInset: frame.rightInset
        text: visible ? panel.badge.detail : ""
        bottomPadding: 6
    }

    // notifyd is down. The countdown is the backoff in
    // Model.socketLost; R or the button skips it.
    CentreMessage {
        visible: panel.view.kind === "offline"
        title: "Notifications offline"
        warn: true
        detail: "notifyd is not answering on " + panel.service.socketPath
            + ". Notifications will not show until it is back."
            + (panel.view.kind === "offline" && panel.view.retryInSeconds > 0
                ? " Trying again in " + panel.view.retryInSeconds + " s." : "")
        actionText: "Try again now"
        rightInset: frame.rightInset
        onActionClicked: panel.service.reconnectNow()
    }

    CentreMessage {
        visible: panel.view.kind === "connecting"
        title: "Connecting to notifyd"
        detail: "Waiting for the notification list."
        rightInset: frame.rightInset
    }

    CentreMessage {
        visible: panel.view.kind === "empty"
        title: "No notifications"
        detail: "New notifications from this desktop, your other desktops and your agents appear here."
        rightInset: frame.rightInset
    }

    PlatinumMenuParts.Separator { visible: frame.showList }

    PlatinumMenuList {
        id: list

        visible: frame.showList
        model: ScriptModel { values: panel.service.items }

        readonly property var current: Model.itemAt(panel.service.items, currentIndex)

        Component.onCompleted: {
            view.forceActiveFocus();
            currentIndex = count > 0 ? 0 : -1;
            Qt.callLater(list.takeRequest);
        }

        // A popup's "Show all" lands here, on its open card.
        function takeRequest() {
            const request = panel.service.takeFocusRequest();
            if (request.kind === "none") return;
            const index = panel.service.items.findIndex(function (i) { return i.id === request.value; });
            if (index < 0) return;
            currentIndex = index;
            view.positionViewAtIndex(index, ListView.Beginning);
        }

        // Move among the selected card's actions, and scroll the
        // focused button into view: a card with many actions can
        // be taller than the list.
        function moveAction(delta) {
            if (list.current.kind === "none") return;
            panel.keyboardUsed = true;
            panel.actionFocus = Model.moveActionFocus(panel.actionFocus,
                list.current.value.actions.length, delta);
            Qt.callLater(list.revealAction);
        }

        function revealAction() {
            if (panel.actionFocus.kind !== "action") return;
            const row = view.itemAtIndex(list.currentIndex);
            const button = row ? row.actionButton(panel.actionFocus.index) : null;
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

        onCurrentIndexChanged: panel.actionFocus = Model.noActionFocus()
        onCountChanged: {
            if (count > 0 && currentIndex < 0) currentIndex = 0;
            if (currentIndex >= count) currentIndex = count - 1;
        }
        onVisibleChanged: if (visible) view.forceActiveFocus()

        function move(offset) {
            if (count === 0) return;
            panel.keyboardUsed = true;
            currentIndex = Math.max(0, Math.min(count - 1, currentIndex + offset));
            view.positionViewAtIndex(currentIndex, ListView.Contain);
        }

        function runAction(index) {
            if (list.current.kind === "none") return;
            const item = list.current.value;
            if (index < 0 || index >= item.actions.length) return;
            panel.service.invoke(item.id, item.actions[index].key);
        }

        view.Keys.priority: Keys.BeforeItem
        view.Keys.onPressed: function (event) {
            const current = list.current;
            if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                list.move(-1);
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                list.move(1);
            } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                panel.keyboardUsed = true;
                if (event.modifiers & Qt.ShiftModifier) panel.service.dismissAll();
                else if (current.kind === "some") panel.service.dismiss(current.value.id);
            } else if (event.key === Qt.Key_Right
                       || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                list.moveAction(1);
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab
                       || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                list.moveAction(-1);
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                panel.keyboardUsed = true;
                if (current.kind === "some") {
                    const action = Model.enterTarget(panel.actionFocus, current.value);
                    if (action.kind === "some") list.runAction(action.value.index);
                }
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_E) {
                panel.keyboardUsed = true;
                if (current.kind === "some") panel.service.toggleExpanded(current.value.id);
            } else if (event.key === Qt.Key_PageDown) {
                list.scrollBy(view.height * 0.9);
            } else if (event.key === Qt.Key_PageUp) {
                list.scrollBy(-view.height * 0.9);
            } else if (event.key === Qt.Key_Home) {
                view.contentY = view.originY;
            } else if (event.key === Qt.Key_End) {
                list.scrollBy(view.contentHeight);
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                panel.keyboardUsed = true;
                list.runAction(event.key - Qt.Key_1);
            } else {
                return;
            }
            event.accepted = true;
        }

        delegate: PlatinumNotificationMenuCard {
            required property var modelData
            required property int index

            item: modelData
            width: ListView.view.width
            rightInset: frame.rightInset
            now: clock.now
            bodyLines: frame.maxHeight >= 600 ? 6 : 3
            lastRow: index === list.count - 1
            expanded: panel.service.expandedIds[modelData.id] === true
            selected: panel.keyboardUsed && list.currentIndex === index
            actionFocus: selected ? panel.actionFocus : Model.noActionFocus()

            onDismissRequested: panel.service.dismiss(modelData.id)
            onActionRequested: function (key) { panel.service.invoke(modelData.id, key); }
            onExpandToggled: panel.service.toggleExpanded(modelData.id)
            onBodyClicked: {
                list.currentIndex = index;
                const fallback = Model.defaultAction(modelData);
                if (fallback.kind === "some" && modelData.sender_alive)
                    panel.service.invoke(modelData.id, fallback.value.action.key);
            }
        }
    }

    PlatinumMenuParts.Hint {
        visible: frame.showList && frame.maxHeight >= 400
        rightInset: frame.rightInset
        text: "↑↓ select · ←→ or Tab action · 1–9 run · Enter run · Del dismiss · Space more · PgUp PgDn scroll · Esc close"
    }

    Shortcut {
        sequence: "R"
        context: Qt.WindowShortcut
        enabled: panel.view.kind === "offline"
        onActivated: panel.service.reconnectNow()
    }


    // A whole-menu message for a view with no list.
    component CentreMessage: ColumnLayout {
        id: message
        property string title: ""
        property string detail: ""
        property bool warn: false
        property string actionText: ""
        property real rightInset: PlatinumTokens.menuRightInset
        signal actionClicked

        Layout.fillWidth: true
        Layout.leftMargin: PlatinumTokens.menuTextLeft
        Layout.rightMargin: rightInset
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        spacing: 6

        Text {
            Layout.fillWidth: true
            text: message.title
            wrapMode: Text.Wrap
            color: message.warn ? PlatinumTokens.menuWarning : PlatinumTokens.menuText
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumText
            font.letterSpacing: PlatinumTokens.platinumTracking
        }

        Text {
            Layout.fillWidth: true
            text: message.detail
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: PlatinumTokens.menuTextSecondary
            font.family: PlatinumTokens.platinumFont
            font.pixelSize: PlatinumTokens.platinumSmall
            font.letterSpacing: PlatinumTokens.platinumTracking
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
