import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "notification-model.js" as Model

// The notification centre: every open item, on every screen's top bar. The
// same shape as the other panels: a Scope that owns the state, a LazyLoader
// that only builds the window while it is shown, a full-screen transparent
// veil with a Hyprland focus grab, and one card anchored under the bar.
//
// Layout is Model.centrePlan of the veil's size. Dismiss all and close stay
// in the title row at every width; the status badge is a readout and moves
// to its own row first. The list scrolls, and each card keeps all of its
// actions (see NotificationCard).
Scope {
    id: root

    required property var service
    required property var screen
    property bool shown: false
    signal closeRequested

    property bool keyboardUsed: false
    // Which action on the selected card the keyboard is on. It goes back to
    // none whenever the selection moves.
    property var actionFocus: Model.noActionFocus()

    onShownChanged: if (root.shown) {
        root.keyboardUsed = false;
        root.actionFocus = Model.noActionFocus();
    }

    // One tagged value decides what the card shows: offline, connecting,
    // empty or ready (Model.viewState). Each block below selects itself.
    readonly property var view: root.service.view
    readonly property var badge: Model.statusBadge(root.view, root.service.status)

    LazyLoader {
        active: root.shown

        PanelWindow {
            id: veil

            screen: root.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            color: "transparent"
            WlrLayershell.namespace: "mountainous-notification-centre"

            HyprlandFocusGrab {
                active: root.shown
                windows: [ veil ]
                onCleared: root.closeRequested()
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeRequested()
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

            Rectangle {
                id: card

                readonly property var plan: Model.centrePlan(veil.width, veil.height)
                readonly property bool showList: root.view.kind === "ready"
                readonly property string badgeText: root.badge.kind === "none" ? "" : root.badge.text
                // The badge joins the title row only while the title and its
                // count keep their full width there.
                readonly property bool badgeInline: !plan.badgeOwnRow && root.badge.kind !== "none"
                    && titleText.implicitWidth + inlineBadge.implicitWidth + dismissAllButton.implicitWidth
                        + 30 + 3 * 6 <= content.width

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 32
                anchors.rightMargin: 6
                width: plan.cardWidth
                // Grow with the items, up to what the screen allows.
                height: Math.max(0, Math.min(content.implicitHeight + 2 * plan.padding, plan.maxHeight))
                radius: Theme.radiusLarge
                color: Theme.bgPanel
                border.width: 1
                border.color: Theme.borderMuted

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: card.plan.padding
                    spacing: 8

                    // Title row. The two controls on the right never leave it.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 6

                        Text {
                            id: titleText
                            Layout.fillWidth: true
                            text: root.view.kind === "ready"
                                ? "Notifications  " + root.service.count
                                : "Notifications"
                            elide: Text.ElideRight
                            color: Theme.textPrimary
                            font.pixelSize: 14
                            font.family: Theme.fontFamily
                            font.bold: true
                        }

                        StatusBadge {
                            id: inlineBadge
                            visible: card.badgeInline
                            text: card.badgeText
                            warn: root.badge.kind === "local_only"
                        }

                        NotificationButton {
                            id: dismissAllButton
                            text: card.plan.dismissAllLabel
                            enabled: root.view.kind === "ready"
                            onClicked: root.service.dismissAll()
                        }

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: Theme.radiusSmall
                            color: closeArea.containsMouse ? Theme.bgSelected : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: Theme.textSecondary
                                font.pixelSize: 16
                                font.family: Theme.fontFamily
                            }

                            MouseArea {
                                id: closeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.closeRequested()
                            }
                        }
                    }

                    StatusBadge {
                        visible: !card.badgeInline && root.badge.kind !== "none"
                        Layout.maximumWidth: content.width
                        text: card.badgeText
                        warn: root.badge.kind === "local_only"
                    }

                    // Why the server is out of reach, in the daemon's words.
                    Text {
                        Layout.fillWidth: true
                        visible: root.badge.kind === "local_only"
                        text: {
                            let value = "New notifications stay on this desktop until the sync server answers.";
                            if (root.service.status.last_error)
                                value += " Last error: " + root.service.status.last_error;
                            return value;
                        }
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        color: Theme.textDetail
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
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
                        onActionClicked: root.service.reconnectNow()
                    }

                    CentreMessage {
                        visible: root.view.kind === "connecting"
                        title: "Connecting to notifyd"
                        detail: "Waiting for the notification list."
                    }

                    CentreMessage {
                        visible: root.view.kind === "empty"
                        title: "No notifications"
                        detail: "New notifications from this desktop, your other desktops and your agents appear here."
                    }

                    ListView {
                        id: list

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: contentHeight
                        visible: card.showList
                        clip: true
                        spacing: 0
                        focus: true
                        boundsBehavior: Flickable.StopAtBounds
                        // Shows that more items exist below the fold.
                        ScrollIndicator.vertical: ScrollIndicator { }
                        model: ScriptModel { values: root.service.items }

                        readonly property var current: Model.itemAt(root.service.items, currentIndex)

                        Component.onCompleted: {
                            forceActiveFocus();
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
                            positionViewAtIndex(index, ListView.Beginning);
                        }

                        // Move among the selected card's actions, and scroll
                        // the focused button into view: a card with many
                        // actions can be taller than the list.
                        function moveAction(delta) {
                            if (list.current.kind === "none") return;
                            root.keyboardUsed = true;
                            root.actionFocus = Model.moveActionFocus(root.actionFocus,
                                list.current.value.actions.length, delta);
                            Qt.callLater(list.revealAction);
                        }

                        function revealAction() {
                            if (root.actionFocus.kind !== "action") return;
                            const row = list.itemAtIndex(list.currentIndex);
                            const button = row ? row.actionButton(root.actionFocus.index) : null;
                            if (!button) return;
                            const top = button.mapToItem(list.contentItem, 0, 0).y;
                            const margin = 8;
                            if (top - margin < list.contentY) list.contentY = top - margin;
                            else if (top + button.height + margin > list.contentY + list.height)
                                list.contentY = top + button.height + margin - list.height;
                        }

                        // An open card can be taller than the list. These
                        // keys move through it a page at a time.
                        function scrollBy(pixels) {
                            const top = originY;
                            const bottom = originY + Math.max(0, contentHeight - height);
                            contentY = Math.max(top, Math.min(bottom, contentY + pixels));
                        }
                        // Hidden while offline, which drops focus. Take it back.
                        onVisibleChanged: if (visible) forceActiveFocus()
                        onCurrentIndexChanged: root.actionFocus = Model.noActionFocus()
                        onCountChanged: {
                            if (count > 0 && currentIndex < 0) currentIndex = 0;
                            if (currentIndex >= count) currentIndex = count - 1;
                        }

                        function move(offset) {
                            if (count === 0) return;
                            root.keyboardUsed = true;
                            currentIndex = Math.max(0, Math.min(count - 1, currentIndex + offset));
                            positionViewAtIndex(currentIndex, ListView.Contain);
                        }

                        function runAction(index) {
                            if (list.current.kind === "none") return;
                            const item = list.current.value;
                            if (index < 0 || index >= item.actions.length) return;
                            root.service.invoke(item.id, item.actions[index].key);
                        }

                        // Item scope is safe here: nothing in the centre takes
                        // focus from the list.
                        Keys.priority: Keys.BeforeItem
                        Keys.onPressed: function (event) {
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
                                list.scrollBy(list.height * 0.9);
                            } else if (event.key === Qt.Key_PageUp) {
                                list.scrollBy(-list.height * 0.9);
                            } else if (event.key === Qt.Key_Home) {
                                list.contentY = list.originY;
                            } else if (event.key === Qt.Key_End) {
                                list.scrollBy(list.contentHeight);
                            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                                root.keyboardUsed = true;
                                list.runAction(event.key - Qt.Key_1);
                            } else {
                                return;
                            }
                            event.accepted = true;
                        }

                        delegate: NotificationCard {
                            id: row

                            required property var modelData
                            required property int index

                            item: modelData
                            width: list.width
                            now: clock.now
                            bodyLines: card.plan.bodyLines
                            framed: false
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

                    Text {
                        Layout.fillWidth: true
                        visible: card.plan.showHint && card.showList
                        text: "↑↓ select  ←→ or Tab action  1–9 run  Enter run  Del dismiss  Space more  PgUp PgDn scroll  Esc close"
                        wrapMode: Text.Wrap
                        color: Theme.textDetail
                        font.pixelSize: 9
                        font.family: Theme.fontFamily
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.WindowShortcut
                onActivated: root.closeRequested()
            }

            Shortcut {
                sequence: "R"
                context: Qt.WindowShortcut
                enabled: root.view.kind === "offline"
                onActivated: root.service.reconnectNow()
            }
        }
    }

    // A whole-card message for a view with no list. Shown only for its own
    // view kind.
    component CentreMessage: ColumnLayout {
        id: message
        property string title: ""
        property string detail: ""
        property bool warn: false
        property string actionText: ""
        signal actionClicked

        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        spacing: 6

        Text {
            Layout.fillWidth: true
            text: message.title
            wrapMode: Text.Wrap
            color: message.warn ? Theme.warning : Theme.textSecondary
            font.pixelSize: 12
            font.family: Theme.fontFamily
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            text: message.detail
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Theme.textMuted
            font.pixelSize: 11
            font.family: Theme.fontFamily
        }

        NotificationButton {
            visible: message.actionText !== ""
            text: message.actionText
            onClicked: message.actionClicked()
        }
    }

    // The "Local only" badge, or the quieter connecting note.
    component StatusBadge: Rectangle {
        property string text: ""
        property bool warn: false
        implicitWidth: badgeText.implicitWidth + 12
        implicitHeight: Math.max(20, badgeText.contentHeight + 6)
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        radius: Theme.radiusSmall
        color: "transparent"
        border.width: 1
        border.color: warn ? Theme.warning : Theme.bgSeparator

        // Wraps rather than cut, if the card is ever this narrow.
        Text {
            id: badgeText
            x: 6
            width: parent.width - 12
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.Wrap
            text: parent.text
            color: parent.warn ? Theme.warning : Theme.textMuted
            font.pixelSize: 10
            font.family: Theme.fontFamily
        }
    }
}
