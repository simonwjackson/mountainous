pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "notification-model.js" as Model

// The notification centre as a Win98 window: the sync status, Dismiss all,
// then the notifications as cards in a sunken list that scrolls. Offline,
// connecting and empty each say what to do. The shared NotificationCentre
// and the notification service own the items, the selection's action focus
// and every command.
//
// Keys: Up/Down (J/K) select; Left/Right or Tab move among the card's
// buttons; 1-9 or Enter run one; Del dismisses (Shift+Del all); Space or E
// show more; PgUp/PgDn/Home/End scroll; R reconnects while offline.
Win98Window {
    id: root

    required property var panel

    readonly property var service: panel.service
    readonly property string kind: panel.view.kind
    readonly property bool ready: kind === "ready"
    readonly property bool warnBadge: panel.badge.kind === "local_only" || panel.badge.kind === "delivery_error"
    readonly property var current: Model.itemAt(service.items, list.currentIndex)

    title: ready ? "Notifications  " + (service.count > 99 ? "99+" : service.count) : "Notifications"
    iconName: "bell"
    onCloseClicked: MenuState.close()

    // A short screen: the card list gives up height first (to 80 u), then
    // the key hint goes; the body scrolls only after that.
    readonly property real listNatural: 260 * u
    readonly property real listMin: 80 * u
    // Measured after layout settles, not bound: the list's height feeds
    // the window's own height, so a binding would loop. The sum is a fixed
    // point (what the list gives up, it adds back).
    property real natural: 0
    function measureNatural() { root.natural = implicitHeight + (well.visible ? listNatural - well.height : 0)
        + (hintArea.visible || !ready ? 0 : hint.height + 8 * u); }
    Connections {
        target: root
        function onImplicitHeightChanged() { Qt.callLater(root.measureNatural); }
    }
    Component.onCompleted: Qt.callLater(root.measureNatural)
    readonly property real squeeze: availableHeight > 0 ? Math.max(0, natural - availableHeight) : 0
    readonly property bool dropStatus: squeeze > (well.visible ? listNatural - listMin : 0) + 0.5
    readonly property real listHeight: Math.max(listMin, Math.floor((listNatural - squeeze) / u) * u)

    // The desktop's minute clock: "4 min" needs no finer step.
    required property date now

    function move(d) {
        if (list.count === 0) return;
        root.panel.keyboardUsed = true;
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + d));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
    function moveAction(d) {
        if (root.current.kind === "none") return;
        root.panel.keyboardUsed = true;
        root.panel.actionFocus = Model.moveActionFocus(root.panel.actionFocus, root.current.value.actions.length, d);
    }
    function runAction(i) {
        if (root.current.kind === "none") return;
        const item = root.current.value;
        if (i >= 0 && i < item.actions.length) root.service.invoke(item.id, item.actions[i].key);
    }
    function scrollBy(px) {
        const max = Math.max(0, list.contentHeight - list.height);
        list.contentY = Math.max(list.originY, Math.min(list.originY + max, list.contentY + px));
    }

    Column {
        id: body
        width: root.bodyWidth
        spacing: 6 * root.u

        Item {
            width: parent.width
            height: 21 * root.u
            Win98Text {
                y: 4 * root.u
                width: Math.min(implicitWidth, parent.width - all.width - 6 * root.u)
                text: root.panel.badge.kind !== "none" ? root.panel.badge.text
                    : root.ready ? "From this desktop and your other devices" : ""
                accessMarks: false
                color: root.panel.badge.kind !== "none" ? Win98Tokens.warning : Win98Tokens.gray
            }
            Win98Button {
                id: all
                x: parent.width - width
                small: true
                text: "&Dismiss all"
                enabled: root.ready
                onClicked: root.service.dismissAll()
            }
        }

        Win98Text {
            visible: root.warnBadge && !!root.panel.badge.detail
            width: parent.width
            wrap: true
            text: root.panel.badge.detail || ""
            accessMarks: false
            color: Win98Tokens.warning
        }

        // offline, connecting, empty
        Item {
            visible: !root.ready
            width: parent.width
            height: visible ? message.height - 3 * root.u : 0
            Win98GroupBox {
                id: message
                y: -3 * root.u
                width: parent.width
                title: root.kind === "offline" ? "Notifications offline" : root.kind === "connecting" ? "Connecting to notifyd" : "No notifications"
                titleColor: root.kind === "offline" ? Win98Tokens.warning : Win98Tokens.text
                Column {
                    width: body.width - 14 * root.u
                    spacing: 5 * root.u
                    Win98Text {
                        width: parent.width
                        wrap: true
                        accessMarks: false
                        text: root.kind === "offline"
                            ? "notifyd is not answering on " + root.service.socketPath + ". Notifications will not show until it is back."
                                + (root.panel.view.retryInSeconds > 0 ? " Trying again in " + root.panel.view.retryInSeconds + " s." : "")
                            : root.kind === "connecting" ? "Waiting for the notification list."
                            : "New notifications from this desktop, your other desktops and your agents appear here."
                    }
                    Item {
                        visible: root.kind === "offline"
                        width: parent.width
                        height: visible ? 23 * root.u : 0
                        Win98Button {
                            x: parent.width - width
                            text: "Try again now"
                            isDefault: true
                            showFocus: true
                            onClicked: root.service.reconnectNow()
                        }
                    }
                }
            }
        }

        Win98Bevel {
            id: well
            visible: root.ready
            width: parent.width
            height: root.listHeight
            variant: "field"
            ListView {
                id: list
                x: 2 * root.u; y: 2 * root.u
                // The scroll bar takes its room once the cards overflow. A
                // narrower list only grows taller, so the choice is stable;
                // it is made again when the list changes.
                property bool roomForBar: count > 3
                onContentHeightChanged: if (contentHeight > height + 0.5) roomForBar = true
                width: well.width - 4 * root.u - (roomForBar ? 18 * root.u : 0)
                height: well.height - 4 * root.u
                clip: true
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel { values: root.service.items }
                currentIndex: 0
                focus: true
                onCurrentIndexChanged: root.panel.actionFocus = Model.noActionFocus()
                onCountChanged: {
                    roomForBar = count > 3 || contentHeight > height + 0.5;
                    if (count > 0 && currentIndex < 0) currentIndex = 0;
                    if (currentIndex >= count) currentIndex = count - 1;
                }
                WheelHandler { onWheel: event => root.scrollBy(event.angleDelta.y > 0 ? -40 * root.u : 40 * root.u) }
                delegate: Card {}
            }
            Win98ScrollBar {
                id: bar
                visible: list.roomForBar
                x: well.width - 2 * root.u - width
                y: 2 * root.u
                height: well.height - 4 * root.u
                flickable: list
                step: 20 * root.u
            }
        }

        Item {
            id: hintArea
            visible: root.ready && !root.dropStatus
            width: parent.width
            height: visible ? hint.height + 2 * root.u : 0
            Win98StatusBar {
                id: hint
                y: 2 * root.u
                width: parent.width
                panes: ["\u2191\u2193 select \u00b7 \u2190\u2192 or Tab action \u00b7 1-9 run \u00b7 Enter run \u00b7 Del dismiss \u00b7 Space more \u00b7 Esc close"]
            }
        }
    }

    component Card: Item {
        id: card
        required property var modelData
        required property int index
        readonly property var item: modelData
        readonly property bool selected: ListView.isCurrentItem
        readonly property bool critical: item.urgency === 2
        readonly property bool expanded: root.service.expandedIds && root.service.expandedIds[item.id] === true
        readonly property var enter: selected ? Model.enterTarget(root.panel.actionFocus, item) : Model.noActionFocus()
        readonly property var image: Model.fileUrl(item.image)
        width: ListView.view.width
        height: content.height + (index > 0 ? 7 : 5) * root.u + 6 * root.u

        // The etched line between cards.
        Rectangle { visible: card.index > 0; width: parent.width; height: root.u; color: Win98Tokens.sh }
        Rectangle { visible: card.index > 0; y: root.u; width: parent.width; height: root.u; color: Win98Tokens.hi }

        Win98FocusRect {
            visible: card.selected
            x: 0; y: 2 * root.u
            width: parent.width; height: parent.height - 3 * root.u
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                list.currentIndex = card.index;
                const fallback = Model.defaultAction(card.item);
                if (fallback.kind === "some" && card.item.sender_alive) root.service.invoke(card.item.id, fallback.value.action.key);
            }
        }
        Rectangle {
            x: 4 * root.u; y: (card.index > 0 ? 7 : 5) * root.u
            width: 20 * root.u; height: 20 * root.u
            color: ["#008080", "#800080", "#000080", "#808000"][Math.max(0, card.index || 0) % 4]
            Win98Text {
                x: Win98Tokens.half((parent.width - width) / 2, root.u)
                y: Win98Tokens.snap((parent.height - height) / 2, root.u)
                text: Model.appLabel(card.item).charAt(0).toUpperCase()
                accessMarks: false
                color: "#ffffff"
            }
        }
        Column {
            id: content
            x: 30 * root.u; y: (card.index > 0 ? 7 : 5) * root.u
            width: card.width - x - 4 * root.u
            spacing: 2 * root.u
            Item {
                width: parent.width
                height: 13 * root.u
                Win98Text {
                    width: Math.max(0, Math.min(implicitWidth, meta.x - 6 * root.u))
                    text: Model.appLabel(card.item)
                    accessMarks: false
                    color: Win98Tokens.gray
                }
                Win98Text {
                    id: meta
                    x: close.x - 6 * root.u - width
                    text: [Model.originLabel(card.item), Model.relativeTime(card.item.updated, root.now.getTime(), Model.localOffsetMinutes(root.now.getTime()))]
                        .filter(function (s) { return s !== ""; }).join(" ")
                    accessMarks: false
                    color: Win98Tokens.gray
                }
                Item {
                    id: close
                    x: parent.width - width
                    width: 14 * root.u; height: 12 * root.u
                    Win98Bevel { anchors.fill: parent; variant: closeArea.pressed ? "pressed" : "button" }
                    Win98Icon {
                        name: "close"
                        x: Win98Tokens.half((close.width - width) / 2, root.u) + (closeArea.pressed ? root.u : 0)
                        y: Win98Tokens.snap((close.height - height) / 2, root.u) + (closeArea.pressed ? root.u : 0)
                    }
                    MouseArea { id: closeArea; anchors.fill: parent; onClicked: root.service.dismiss(card.item.id) }
                }
            }
            Item {
                width: parent.width
                height: Math.max(words.height, card.image.kind === "some" ? 40 * root.u : 0)
                Image {
                    id: picture
                    visible: card.image.kind === "some"
                    x: parent.width - width
                    y: 2 * root.u
                    width: visible ? 48 * root.u : 0
                    height: 36 * root.u
                    fillMode: Image.PreserveAspectCrop
                    source: card.image.kind === "some" ? card.image.value : ""
                    sourceSize.width: 96
                    sourceSize.height: 72
                    Rectangle { anchors.fill: parent; color: "transparent"; border.width: root.u; border.color: Win98Tokens.dk }
                }
                Column {
                    id: words
                    width: parent.width - (picture.visible ? picture.width + 6 * root.u : 0)
                    spacing: 2 * root.u
                    Win98Text {
                        visible: Model.headline(card.item) !== ""
                        width: Math.min(implicitWidth, parent.width)
                        text: Model.headline(card.item)
                        accessMarks: false
                        bold: true
                        color: card.critical ? Win98Tokens.danger : Win98Tokens.text
                    }
                    Win98Text {
                        visible: card.item.body !== ""
                        width: parent.width
                        wrap: true
                        maximumLineCount: card.expanded ? 1000 : 3
                        text: card.item.body
                        accessMarks: false
                    }
                }
            }
            Tag { visible: card.critical; text: "Urgent, stays until dismissed"; color: Win98Tokens.danger }
            Tag { visible: card.item.local_only === true; text: Model.localOnlyLabel(card.item) + ", not synced"; color: Win98Tokens.gray }
            Win98Text {
                visible: !card.item.sender_alive && card.item.actions.length > 0
                width: parent.width
                wrap: true
                text: "The app that sent this has closed. Its buttons no longer work."
                accessMarks: false
                color: Win98Tokens.gray
            }
            Item {
                visible: card.item.actions.length > 0
                width: parent.width
                height: visible ? 24 * root.u : 0
                Flow {
                    y: 3 * root.u
                    width: parent.width
                    spacing: 4 * root.u
                    Repeater {
                        model: card.item.actions
                        Win98Button {
                            required property var modelData
                            required property int index
                            small: true
                            text: Model.buttonLabel(modelData).replace(/&/g, "&&")
                            enabled: card.item.sender_alive
                            showFocus: card.selected && card.enter.kind === "some" && card.enter.value.index === index
                            onClicked: root.service.invoke(card.item.id, modelData.key)
                        }
                    }
                }
            }
        }
    }

    component Tag: Item {
        id: tag
        property string text: ""
        property color color: Win98Tokens.text
        width: label.width + 8 * root.u
        height: visible ? 13 * root.u : 0
        Rectangle { anchors.fill: parent; color: "transparent"; border.width: root.u; border.color: tag.color }
        Win98Text { id: label; x: 4 * root.u; text: tag.text; accessMarks: false; color: tag.color }
    }

    Shortcut { sequences: ["Up", "K"]; context: Qt.WindowShortcut; enabled: root.ready; onActivated: root.move(-1) }
    Shortcut { sequences: ["Down", "J"]; context: Qt.WindowShortcut; enabled: root.ready; onActivated: root.move(1) }
    Shortcut { sequences: ["Right", "Tab"]; context: Qt.WindowShortcut; enabled: root.ready; onActivated: root.moveAction(1) }
    Shortcut { sequences: ["Left", "Backtab"]; context: Qt.WindowShortcut; enabled: root.ready; onActivated: root.moveAction(-1) }
    Shortcut {
        sequences: ["Return", "Enter"]
        context: Qt.WindowShortcut
        enabled: root.ready
        onActivated: {
            root.panel.keyboardUsed = true;
            if (root.current.kind !== "some") return;
            const a = Model.enterTarget(root.panel.actionFocus, root.current.value);
            if (a.kind === "some") root.runAction(a.value.index);
        }
    }
    Shortcut { sequences: ["Space", "E"]; context: Qt.WindowShortcut; enabled: root.ready && root.current.kind === "some"; onActivated: root.service.toggleExpanded(root.current.value.id) }
    Shortcut { sequences: ["Delete", "Backspace"]; context: Qt.WindowShortcut; enabled: root.ready && root.current.kind === "some"; onActivated: root.service.dismiss(root.current.value.id) }
    Shortcut { sequence: "Shift+Delete"; context: Qt.WindowShortcut; enabled: root.ready; onActivated: root.service.dismissAll() }
    Shortcut { sequence: "PgDown"; context: Qt.WindowShortcut; onActivated: root.scrollBy(list.height * 0.9) }
    Shortcut { sequence: "PgUp"; context: Qt.WindowShortcut; onActivated: root.scrollBy(-list.height * 0.9) }
    Shortcut { sequence: "Home"; context: Qt.WindowShortcut; onActivated: list.contentY = list.originY }
    Shortcut { sequence: "End"; context: Qt.WindowShortcut; onActivated: root.scrollBy(list.contentHeight) }
    Shortcut { sequence: "R"; context: Qt.WindowShortcut; enabled: root.kind === "offline"; onActivated: root.service.reconnectNow() }
    Repeater {
        model: 9
        Item {
            id: digit
            required property int index
            Shortcut { sequence: String(digit.index + 1); context: Qt.WindowShortcut; enabled: root.ready; onActivated: root.runAction(digit.index) }
        }
    }
}
