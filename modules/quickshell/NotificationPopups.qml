import Quickshell
import Quickshell.Wayland
import QtQuick
import "notification-model.js" as Model

// The popup stack, top right under the bar, newest first. A popup is a view
// of an open item, nothing more: its timeout only hides it, and the item
// stays in the centre (contract section 5, "Popup timeout").
//
// The window is only as big as its cards, so it never blocks the pointer
// anywhere else, and it never takes the keyboard. Every popup capability is
// also in the centre, where the keyboard reaches it.
Scope {
    id: root

    required property var service
    required property var screen
    // True while a centre is open; the centre already shows these items.
    property bool suppressed: false
    signal openCentreRequested

    readonly property bool active: !root.suppressed && root.service.popups.length > 0

    // "Show all": the centre opens with this item's card open. Deferred,
    // because both steps remove the popup that asked, and its handler must
    // not run on in a destroyed delegate.
    function openItem(id) {
        Qt.callLater(function () {
            root.service.revealItem(id);
            root.openCentreRequested();
        });
    }

    // Anything that arrives while the centre is open is already in front of
    // the reader, so it does not pop up again when the centre closes.
    onSuppressedChanged: if (root.suppressed) root.service.hideAllPopups()
    Connections {
        target: root.service
        function onPopupsChanged() {
            if (root.suppressed && root.service.popups.length > 0) root.service.hideAllPopups();
        }
    }

    LazyLoader {
        active: root.active

        PanelWindow {
            id: win

            screen: root.screen
            anchors { top: true; right: true }
            // Zero keeps the stack below the bar's reserved space without
            // reserving any space of its own.
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 0
            margins { top: 6; right: 6 }
            // Above a fullscreen window only while an urgent item shows.
            WlrLayershell.layer: root.service.popups.some(function (id) {
                const found = root.service.find(id);
                return found.kind === "some" && found.value.urgency === 2;
            }) ? WlrLayer.Overlay : WlrLayer.Top
            WlrLayershell.namespace: "mountainous-notifications"
            color: "transparent"

            readonly property var plan: Model.popupPlan(
                win.screen ? win.screen.width : 0,
                win.screen ? win.screen.height : 0)
            readonly property var ids: root.service.popups.slice(0, win.plan.maxCount)
            property int visibleCount: 1
            readonly property int hiddenCount: root.service.popups.length - win.visibleCount

            // Fit the newest cards into the screen's height, measured from the
            // cards themselves. See Model.fitPopups.
            function relayout() {
                const heights = [];
                for (let i = 0; i < cards.count; i++) {
                    const card = cards.itemAt(i);
                    heights.push(card ? card.implicitHeight : 0);
                }
                for (let j = cards.count; j < root.service.popups.length; j++) heights.push(0);
                const fit = Model.fitPopups(heights, win.plan.maxHeight, win.plan.gap,
                    win.plan.chipHeight, win.plan.maxCount);
                win.visibleCount = Math.max(1, fit.visible);
            }

            implicitWidth: Math.max(1, win.plan.cardWidth)
            implicitHeight: Math.max(1, Math.min(win.plan.maxHeight, stack.implicitHeight))
            onPlanChanged: Qt.callLater(win.relayout)
            onIdsChanged: Qt.callLater(win.relayout)

            Column {
                id: stack
                width: win.plan.cardWidth
                spacing: win.plan.gap

                Repeater {
                    id: cards
                    model: ScriptModel { values: win.ids }

                    delegate: NotificationCard {
                        id: popup

                        required property var modelData
                        required property int index

                        readonly property bool hovered: hover.hovered

                        readonly property var found: root.service.find(modelData)
                        item: found.kind === "some" ? found.value : Model.placeholderItem(modelData)
                        readonly property var timeout: Model.popupTimeout(popup.item)
                        width: win.plan.cardWidth
                        visible: index < win.visibleCount
                        bodyLines: win.plan.bodyLines
                        now: clock.now
                        showClock: true
                        remaining: 1
                        moreText: "Show all in Notifications"

                        onImplicitHeightChanged: Qt.callLater(win.relayout)
                        onDismissRequested: root.service.dismiss(modelData)
                        onExpandToggled: root.openItem(modelData)
                        onActionRequested: function (key) { root.service.invoke(modelData, key); }
                        onBodyClicked: {
                            const fallback = Model.defaultAction(popup.item);
                            if (fallback.kind === "some" && popup.item.sender_alive)
                                root.service.invoke(modelData, fallback.value.action.key);
                            else root.service.hidePopup(modelData);
                        }

                        HoverHandler { id: hover }

                        // The timeout. It pauses while the pointer rests on
                        // the popup, and starts again when the daemon marks
                        // the same item fresh. An urgent item has none.
                        NumberAnimation on remaining {
                            id: countdown
                            from: 1
                            to: 0
                            duration: popup.timeout.kind === "after" ? popup.timeout.ms : 1
                            running: popup.timeout.kind === "after" && popup.visible
                            paused: running && popup.hovered
                            onFinished: root.service.hidePopup(popup.modelData)
                        }

                        Connections {
                            target: root.service
                            function onPopupRefreshed(id) {
                                if (id === popup.modelData) countdown.restart();
                            }
                        }
                    }
                }

                // The rest of the stack, one click from the centre.
                NotificationButton {
                    visible: win.hiddenCount > 0
                    width: win.plan.cardWidth
                    height: win.plan.chipHeight
                    quiet: false
                    maxWidth: win.plan.cardWidth
                    text: win.hiddenCount === 1
                        ? "1 more in Notifications"
                        : win.hiddenCount + " more in Notifications"
                    onClicked: root.openCentreRequested()
                }
            }

            QtObject {
                id: clock
                property double now: Date.now()
            }

            Timer {
                interval: 30000
                running: true
                repeat: true
                onTriggered: clock.now = Date.now()
            }
        }
    }
}
