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

    // Kept on the Scope, so a resize or a new item does not fold a body the
    // reader opened.
    property var expandedIds: ({})
    property bool keyboardUsed: false

    function toggleExpanded(id) {
        const next = Object.assign({}, root.expandedIds);
        if (next[id]) delete next[id];
        else next[id] = true;
        root.expandedIds = next;
    }

    onShownChanged: if (root.shown) root.keyboardUsed = false

    readonly property string badge: Model.serverBadge(root.service.status)
    readonly property string connectingBadge: root.service.online
        && root.service.status.server === "connecting" ? "Connecting to sync server" : ""

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
                readonly property bool showList: root.service.online && root.service.count > 0
                readonly property string badgeText: root.badge !== "" ? root.badge : root.connectingBadge
                // The badge joins the title row only while the title and its
                // count keep their full width there.
                readonly property bool badgeInline: !plan.badgeOwnRow && badgeText !== ""
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
                            text: root.service.online && root.service.count > 0
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
                            warn: root.badge !== ""
                        }

                        NotificationButton {
                            id: dismissAllButton
                            text: card.plan.dismissAllLabel
                            enabled: root.service.online && root.service.count > 0
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
                        visible: !card.badgeInline && text !== ""
                        Layout.maximumWidth: content.width
                        text: card.badgeText
                        warn: root.badge !== ""
                    }

                    // Why the server is out of reach, in the daemon's words.
                    Text {
                        Layout.fillWidth: true
                        visible: root.badge !== ""
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

                    // Daemon down, connecting, or empty: one message block.
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.bottomMargin: 6
                        visible: !card.showList
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (root.service.online) return "No notifications";
                                if (root.service.connecting) return "Connecting to notifyd";
                                return "Notifications offline";
                            }
                            wrapMode: Text.Wrap
                            color: !root.service.online && !root.service.connecting
                                ? Theme.warning : Theme.textSecondary
                            font.pixelSize: 12
                            font.family: Theme.fontFamily
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (root.service.online)
                                    return "New notifications from this desktop, your other desktops and your agents appear here.";
                                if (root.service.connecting)
                                    return "Waiting for the notification list.";
                                return "notifyd is not answering on " + root.service.socketPath
                                    + ". Notifications will not show until it is back."
                                    + (root.service.retryInSeconds > 0
                                        ? " Trying again in " + root.service.retryInSeconds + " s."
                                        : "");
                            }
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Theme.textMuted
                            font.pixelSize: 11
                            font.family: Theme.fontFamily
                        }

                        NotificationButton {
                            visible: !root.service.online && !root.service.connecting
                            text: "Try again now"
                            onClicked: root.service.reconnectNow()
                        }
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

                        readonly property var current: currentIndex >= 0 && currentIndex < root.service.items.length
                            ? root.service.items[currentIndex] : null

                        Component.onCompleted: {
                            forceActiveFocus();
                            currentIndex = count > 0 ? 0 : -1;
                        }
                        // Hidden while offline, which drops focus. Take it back.
                        onVisibleChanged: if (visible) forceActiveFocus()
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
                            const item = list.current;
                            if (!item || index < 0 || index >= item.actions.length) return;
                            root.service.invoke(item.id, item.actions[index].key);
                        }

                        // Item scope is safe here: nothing in the centre takes
                        // focus from the list.
                        Keys.priority: Keys.BeforeItem
                        Keys.onPressed: function (event) {
                            const item = list.current;
                            if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                                list.move(-1);
                            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                                list.move(1);
                            } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                                root.keyboardUsed = true;
                                if (event.modifiers & Qt.ShiftModifier) root.service.dismissAll();
                                else if (item) root.service.dismiss(item.id);
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.keyboardUsed = true;
                                if (item) {
                                    const fallback = Model.defaultAction(item);
                                    list.runAction(fallback ? item.actions.indexOf(fallback) : 0);
                                }
                            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_E) {
                                root.keyboardUsed = true;
                                if (item) root.toggleExpanded(item.id);
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
                            expandable: true
                            framed: false
                            lastRow: index === list.count - 1
                            expanded: root.expandedIds[modelData.id] === true
                            selected: root.keyboardUsed && list.currentIndex === index

                            onDismissRequested: root.service.dismiss(modelData.id)
                            onActionRequested: function (key) { root.service.invoke(modelData.id, key); }
                            onExpandToggled: root.toggleExpanded(modelData.id)
                            onBodyClicked: {
                                list.currentIndex = index;
                                const fallback = Model.defaultAction(modelData);
                                if (fallback && modelData.sender_alive) root.service.invoke(modelData.id, fallback.key);
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: card.plan.showHint && card.showList
                        text: "↑↓ select  1–9 action  Enter open  Del dismiss  Space more  Esc close"
                        elide: Text.ElideRight
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
                enabled: !root.service.online && !root.service.connecting
                onActivated: root.service.reconnectNow()
            }
        }
    }

    // The "Local only" badge, or the quieter connecting note.
    component StatusBadge: Rectangle {
        property string text: ""
        property bool warn: false
        implicitWidth: badgeText.implicitWidth + 12
        implicitHeight: 20
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: 20
        radius: Theme.radiusSmall
        color: "transparent"
        border.width: 1
        border.color: warn ? Theme.warning : Theme.bgSeparator

        Text {
            id: badgeText
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: parent.text
            color: parent.warn ? Theme.warning : Theme.textMuted
            font.pixelSize: 10
            font.family: Theme.fontFamily
        }
    }
}
