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
    // Cut text is always one step from its full form. In the centre that
    // step opens the card in place, and an open card cuts nothing. A popup
    // sends the reader to the centre, with the item open there.
    property bool expandable: true
    property bool expanded: false
    property string moreText: card.expanded ? "Show less" : "Show more"
    // The keyboard's current card in the centre. Drawn as a focus ring.
    property bool selected: false
    // The keyboard's current action on this card (Model.moveActionFocus).
    property var actionFocus: Model.noActionFocus()

    // The button for one action, so the centre can scroll it into view.
    function actionButton(index) {
        return actionButtons.itemAt(index);
    }
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
    readonly property var image: Model.fileUrl(item.image)
    readonly property string imageUrl: image.kind === "some" ? image.value : ""
    property bool imageFailed: false
    readonly property bool hasImage: image.kind === "some" && !imageFailed
    readonly property var plan: Model.cardPlan(card.width, card.hasImage, card.expanded)
    // True while any text on the card is cut short.
    readonly property bool cut: appText.truncated || inlineMeta.truncated || metaLine.truncated
        || headlineText.truncated || bodyText.truncated
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
    readonly property bool hasDefault: Model.defaultAction(item).kind === "some"

    // Paths and icon names both arrive in app_icon; Model.iconChoice sets
    // the order. Quickshell answers a missing icon with "", which these
    // lookups turn into none.
    readonly property var icon: Model.iconChoice(item,
        function (name) {
            const url = Quickshell.iconPath(name, true);
            return url !== "" ? Model.some(url) : Model.none();
        },
        function (appName) {
            const entry = DesktopEntries.heuristicLookup(appName);
            const url = entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : "";
            return url !== "" ? Model.some(url) : Model.none();
        })

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
        spacing: NotificationStyle.gap

        // Title row: who sent it, then the readouts, then dismiss.
        RowLayout {
            Layout.fillWidth: true
            spacing: NotificationStyle.gap

            Item {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16

                IconImage {
                    anchors.fill: parent
                    visible: card.icon.kind === "image"
                    source: card.icon.kind === "image" ? card.icon.url : ""
                    implicitSize: 16
                }

                Rectangle {
                    anchors.fill: parent
                    visible: card.icon.kind === "letter"
                    radius: Theme.radiusSmall
                    color: Theme.bgActive
                    border.width: 1
                    border.color: Theme.borderMuted

                    Text {
                        anchors.centerIn: parent
                        text: card.icon.kind === "letter" ? card.icon.letter : ""
                        color: Theme.textSecondary
                        font.pixelSize: NotificationStyle.textDetail
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
                // undefined resets the limit: an open card shows every line.
                maximumLineCount: card.expanded ? undefined : 1
                elide: Text.ElideRight
                color: Theme.textMuted
                font.pixelSize: NotificationStyle.textDetail
                font.family: Theme.fontFamily
            }

            Text {
                id: inlineMeta
                visible: card.plan.metaInline && card.meta !== ""
                Layout.maximumWidth: card.plan.inner * 0.45
                text: card.meta
                textFormat: Text.PlainText
                elide: Text.ElideLeft
                color: card.item.origin === "remote" ? Theme.textSecondary : Theme.textDetail
                font.pixelSize: NotificationStyle.textDetail
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
                    font.pixelSize: NotificationStyle.textGlyph
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

        // Host and time on their own line once the title row is too narrow,
        // or once the card is open, where the line wraps instead.
        Text {
            id: metaLine
            Layout.fillWidth: true
            visible: !card.plan.metaInline && card.meta !== ""
            text: card.meta
            textFormat: Text.PlainText
            wrapMode: card.expanded ? Text.Wrap : Text.NoWrap
            elide: card.expanded ? Text.ElideNone : Text.ElideRight
            color: card.item.origin === "remote" ? Theme.textSecondary : Theme.textDetail
            font.pixelSize: NotificationStyle.textDetail
            font.family: Theme.fontFamily
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: NotificationStyle.gapWide

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: NotificationStyle.gapTight

                Text {
                    id: headlineText
                    Layout.fillWidth: true
                    visible: card.headline !== ""
                    text: card.headline
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: card.expanded ? undefined : 2
                    elide: Text.ElideRight
                    color: card.low ? Theme.textSecondary : Theme.textPrimary
                    font.pixelSize: NotificationStyle.textTitle
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
                    maximumLineCount: card.expanded ? undefined : card.bodyLines
                    elide: Text.ElideRight
                    color: Theme.textSecondary
                    font.pixelSize: NotificationStyle.textBody
                    font.family: Theme.fontFamily
                    lineHeight: 1.1
                }

                Text {
                    id: moreLink
                    visible: card.expandable && (card.expanded || card.cut)
                    text: card.moreText
                    color: moreArea.containsMouse ? Theme.textPrimary : Theme.accent
                    font.pixelSize: NotificationStyle.textDetail
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

        // Below the text when the card is narrow, and on an open card, where
        // it shows the whole picture at its own shape instead of a crop.
        Rectangle {
            visible: card.plan.imageBelow
            Layout.fillWidth: true
            Layout.preferredHeight: card.expanded && belowImage.implicitWidth > 0
                ? Math.round(width * belowImage.implicitHeight / belowImage.implicitWidth)
                : card.plan.imageBelowHeight
            radius: Theme.radiusSmall
            color: Theme.bgInput
            clip: true

            Image {
                id: belowImage
                anchors.fill: parent
                source: card.plan.imageBelow ? card.imageUrl : ""
                asynchronous: true
                fillMode: card.expanded ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                sourceSize.width: 512
                onStatusChanged: if (status === Image.Error) card.imageFailed = true
            }
        }

        // Facts about the item that change what the reader can expect.
        Flow {
            Layout.fillWidth: true
            visible: card.critical || card.localOnly !== ""
            spacing: NotificationStyle.gap

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
                    font.pixelSize: NotificationStyle.textDetail
                    font.family: Theme.fontFamily
                }
            }

            Rectangle {
                visible: card.localOnly !== ""
                width: Math.min(localText.implicitWidth + 12, content.width)
                height: Math.max(18, localText.height + 4)
                radius: Theme.radiusSmall
                color: "transparent"
                border.width: 1
                border.color: Theme.bgSeparator

                // A host name can be long; the tag wraps rather than cut it.
                Text {
                    id: localText
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 12
                    wrapMode: Text.Wrap
                    text: card.localOnly + ", not synced"
                    textFormat: Text.PlainText
                    color: Theme.textMuted
                    font.pixelSize: NotificationStyle.textDetail
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
            font.pixelSize: NotificationStyle.textDetail
            font.family: Theme.fontFamily
        }

        // Every action, in the app's order. A row that runs out of width
        // wraps; no action is ever dropped.
        Flow {
            Layout.fillWidth: true
            visible: card.item.actions.length > 0
            spacing: NotificationStyle.gap

            Repeater {
                id: actionButtons
                model: card.item.actions

                NotificationButton {
                    required property var modelData
                    required property int index
                    text: Model.buttonLabel(modelData)
                    keyHint: card.selected && index < 9 ? String(index + 1) : ""
                    maxWidth: card.plan.buttonMaxWidth
                    focused: card.actionFocus.kind === "action" && card.actionFocus.index === index
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
