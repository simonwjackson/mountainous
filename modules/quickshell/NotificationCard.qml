import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "notification-model.js" as Model

// One notification, drawn the same way in a popup and in the centre. Its
// layout is a function of its own width only (Model.cardPlan); the caller
// sets the width and reads implicitHeight.
//
// Every capability stays on the card at every width: dismiss in the title
// row, every action in a wrapping row. Readouts give way first: the host and
// time leave the title row for their own line, and a side image moves below
// the text.
Rectangle {
    id: card

    required property var item
    property double now: Date.now()
    // The reader's offset east of UTC at the moment of rendering; see
    // Model.calendarDay.
    property int tzOffsetMinutes: Model.localOffsetMinutes(now)
    property int bodyLines: 3
    // The centre lets a long body open in place; popups send the reader there.
    property bool expandable: false
    property bool expanded: false
    // The keyboard's current card in the centre. Drawn as a focus ring.
    property bool selected: false
    // A popup floats over windows and needs its own edge. A centre row sits
    // in the centre's card, so a rule between rows is enough.
    property bool framed: true
    property bool lastRow: false
    // Popups only: draw the timeout along the bottom edge. remaining is the
    // part left, 1 to 0.
    property bool showClock: false
    property real remaining: 1

    signal dismissRequested
    signal actionRequested(string key)
    signal expandToggled
    signal bodyClicked

    readonly property bool critical: item.urgency === 2
    readonly property bool low: item.urgency === 0
    readonly property string imageUrl: Model.fileUrl(item.image)
    property bool imageFailed: false
    readonly property bool hasImage: imageUrl !== "" && !imageFailed
    readonly property var plan: Model.cardPlan(card.width, card.hasImage)
    readonly property string meta: {
        const parts = [];
        const origin = Model.originLabel(item);
        if (origin !== "") parts.push(origin);
        const when = Model.relativeTime(item.updated, card.now, card.tzOffsetMinutes);
        if (when !== "") parts.push(when);
        return parts.join("  ");
    }
    readonly property string headline: Model.headline(item)
    readonly property string localOnly: Model.localOnlyLabel(item)
    readonly property bool hasDefault: Model.defaultAction(item) !== null

    // Paths and icon names both arrive in app_icon. A missing name falls back
    // to the app's desktop entry, then to its first letter.
    readonly property string iconSource: {
        const path = Model.fileUrl(item.app_icon);
        if (path !== "") return path;
        if (item.app_icon !== "") {
            const named = Quickshell.iconPath(item.app_icon, true);
            if (named !== "") return named;
        }
        if (item.app_name !== "") {
            const entry = DesktopEntries.heuristicLookup(item.app_name);
            if (entry && entry.icon) {
                const fromEntry = Quickshell.iconPath(entry.icon, true);
                if (fromEntry !== "") return fromEntry;
            }
        }
        return "";
    }

    onImageUrlChanged: imageFailed = false

    implicitHeight: content.implicitHeight + 2 * plan.padding + (drain.visible ? 2 : 0)
    radius: card.framed ? Theme.radiusLarge : Theme.radiusMedium
    color: card.framed ? Theme.bgPanel
        : card.selected ? Theme.bgSelected : "transparent"
    border.width: card.selected ? 2 : card.framed ? 1 : 0
    border.color: card.selected ? Theme.accent
        : card.critical ? Theme.danger : Theme.borderMuted
    clip: true

    // An urgent centre row keeps a red edge, as its popup had.
    Rectangle {
        visible: !card.framed && card.critical
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: card.plan.padding
        anchors.bottomMargin: card.plan.padding
        width: 2
        color: Theme.danger
    }

    Rectangle {
        visible: !card.framed && !card.lastRow && !card.selected
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.borderMuted
    }

    // A click on the body runs the app's default action when it has one.
    MouseArea {
        anchors.fill: parent
        cursorShape: card.hasDefault && card.item.sender_alive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: card.bodyClicked()
    }

    ColumnLayout {
        id: content
        x: card.plan.padding
        y: card.plan.padding
        width: card.plan.inner
        spacing: 6

        // Title row: who sent it, then the readouts, then dismiss.
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Item {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16

                IconImage {
                    anchors.fill: parent
                    visible: card.iconSource !== ""
                    source: card.iconSource
                    implicitSize: 16
                }

                Rectangle {
                    anchors.fill: parent
                    visible: card.iconSource === ""
                    radius: Theme.radiusSmall
                    color: Theme.bgActive
                    border.width: 1
                    border.color: Theme.borderMuted

                    Text {
                        anchors.centerIn: parent
                        text: Model.letter(card.item)
                        color: Theme.textSecondary
                        font.pixelSize: 10
                        font.family: Theme.fontFamily
                        font.bold: true
                    }
                }
            }

            Text {
                id: appText
                Layout.fillWidth: true
                text: Model.appLabel(card.item)
                textFormat: Text.PlainText
                wrapMode: card.expanded ? Text.Wrap : Text.NoWrap
                maximumLineCount: card.expanded ? 3 : 1
                elide: Text.ElideRight
                color: Theme.textMuted
                font.pixelSize: 10
                font.family: Theme.fontFamily
            }

            Text {
                visible: card.plan.metaInline && card.meta !== ""
                Layout.maximumWidth: card.plan.inner * 0.45
                text: card.meta
                textFormat: Text.PlainText
                elide: Text.ElideLeft
                color: card.item.origin === "remote" ? Theme.textSecondary : Theme.textDetail
                font.pixelSize: 10
                font.family: Theme.fontFamily
            }

            Rectangle {
                id: dismissButton
                Layout.preferredWidth: 26
                Layout.preferredHeight: 22
                radius: Theme.radiusSmall
                color: dismissArea.pressed ? Theme.bgActive
                    : dismissArea.containsMouse ? Theme.bgSelected : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: dismissArea.containsMouse ? Theme.textPrimary : Theme.textMuted
                    font.pixelSize: 15
                    font.family: Theme.fontFamily
                }

                MouseArea {
                    id: dismissArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.dismissRequested()
                }
            }
        }

        // Host and time on their own line once the title row is too narrow.
        Text {
            Layout.fillWidth: true
            visible: !card.plan.metaInline && card.meta !== ""
            text: card.meta
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: card.item.origin === "remote" ? Theme.textSecondary : Theme.textDetail
            font.pixelSize: 10
            font.family: Theme.fontFamily
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 3

                Text {
                    id: headlineText
                    Layout.fillWidth: true
                    visible: card.headline !== ""
                    text: card.headline
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: card.expanded ? 6 : 2
                    elide: Text.ElideRight
                    color: card.low ? Theme.textSecondary : Theme.textPrimary
                    font.pixelSize: 12
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                // Bodies are plain text. Desktop apps and agents both write
                // here, and markup from either is not trusted.
                Text {
                    id: bodyText
                    Layout.fillWidth: true
                    visible: card.item.body !== ""
                    text: card.item.body
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: card.expanded ? 400 : card.bodyLines
                    elide: Text.ElideRight
                    color: Theme.textSecondary
                    font.pixelSize: 11
                    font.family: Theme.fontFamily
                    lineHeight: 1.1
                }

                Text {
                    id: moreLink
                    visible: card.expandable
                        && (card.expanded || bodyText.truncated || headlineText.truncated || appText.truncated)
                    text: card.expanded ? "Show less" : "Show more"
                    color: moreArea.containsMouse ? Theme.textPrimary : Theme.accent
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                    font.underline: moreArea.containsMouse

                    MouseArea {
                        id: moreArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.expandToggled()
                    }
                }
            }

            Rectangle {
                visible: card.plan.imageSide
                Layout.preferredWidth: card.plan.imageSize
                Layout.preferredHeight: card.plan.imageSize
                Layout.alignment: Qt.AlignTop
                radius: Theme.radiusSmall
                color: Theme.bgInput
                clip: true

                Image {
                    anchors.fill: parent
                    source: card.plan.imageSide ? card.imageUrl : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 128
                    sourceSize.height: 128
                    onStatusChanged: if (status === Image.Error) card.imageFailed = true
                }
            }
        }

        Rectangle {
            visible: card.plan.imageBelow
            Layout.fillWidth: true
            Layout.preferredHeight: card.plan.imageBelowHeight
            radius: Theme.radiusSmall
            color: Theme.bgInput
            clip: true

            Image {
                anchors.fill: parent
                source: card.plan.imageBelow ? card.imageUrl : ""
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 256
                onStatusChanged: if (status === Image.Error) card.imageFailed = true
            }
        }

        // Facts about the item that change what the reader can expect.
        Flow {
            Layout.fillWidth: true
            visible: card.critical || card.localOnly !== ""
            spacing: 6

            Rectangle {
                visible: card.critical
                width: urgentText.implicitWidth + 12
                height: 18
                radius: Theme.radiusSmall
                color: "transparent"
                border.width: 1
                border.color: Theme.danger

                Text {
                    id: urgentText
                    anchors.centerIn: parent
                    text: card.showClock ? "Urgent, stays until dismissed" : "Urgent"
                    color: Theme.danger
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                }
            }

            Rectangle {
                visible: card.localOnly !== ""
                width: Math.min(localText.implicitWidth + 12, content.width)
                height: 18
                radius: Theme.radiusSmall
                color: "transparent"
                border.width: 1
                border.color: Theme.bgSeparator

                Text {
                    id: localText
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: card.localOnly + ", not synced"
                    textFormat: Text.PlainText
                    color: Theme.textMuted
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !card.item.sender_alive && card.item.actions.length > 0
            text: "The app that sent this has closed. Its buttons no longer work."
            wrapMode: Text.Wrap
            color: Theme.warning
            font.pixelSize: 10
            font.family: Theme.fontFamily
        }

        // Every action, in the app's order. A row that runs out of width
        // wraps; no action is ever dropped.
        Flow {
            Layout.fillWidth: true
            visible: card.item.actions.length > 0
            spacing: 6

            Repeater {
                model: card.item.actions

                NotificationButton {
                    required property var modelData
                    required property int index
                    text: Model.buttonLabel(modelData)
                    keyHint: card.selected && index < 9 ? String(index + 1) : ""
                    maxWidth: card.plan.buttonMaxWidth
                    enabled: card.item.sender_alive
                    onClicked: card.actionRequested(modelData.key)
                }
            }
        }
    }

    // The popup's clock. It drains while the popup waits to hide, and stops
    // while the pointer is over it. An urgent popup has a full red edge
    // instead, because it waits for you.
    Rectangle {
        id: drain
        visible: card.showClock
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: card.radius
        anchors.bottomMargin: 1
        height: 2
        width: card.critical
            ? parent.width - 2 * card.radius
            : Math.max(0, (parent.width - 2 * card.radius) * Math.max(0, Math.min(1, card.remaining)))
        color: card.critical ? Theme.danger : Theme.accent
        opacity: card.critical ? 1 : 0.7
    }
}
