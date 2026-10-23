import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "notification-model.js" as Model

// One notification in the centre menu, on the menu grid. The popups keep
// NotificationCard; this is the same item in Platinum.
//
//   gutter  the app's icon, or its first letter in a raised box
//   text    app name; headline; body; tags; actions
//   right   when and where from, then the dismiss box
//
// Every action stays on the card at every width: the actions wrap. Cut
// text is one step from its full form (Show more, or Space).
Item {
    id: card

    required property var item
    property double now: Date.now()
    property int tzOffsetMinutes: Model.localOffsetMinutes(now)
    property int bodyLines: 3
    property bool expanded: false
    property bool selected: false
    property var actionFocus: Model.noActionFocus()
    property bool lastRow: false
    property real rightInset: Theme.menuRightInset

    signal dismissRequested
    signal actionRequested(string key)
    signal expandToggled
    signal bodyClicked

    function actionButton(index) { return actionButtons.itemAt(index); }

    readonly property bool critical: item.urgency === 2
    readonly property bool low: item.urgency === 0
    readonly property var image: Model.fileUrl(item.image)
    readonly property string imageUrl: image.kind === "some" ? image.value : ""
    property bool imageFailed: false
    readonly property bool hasImage: image.kind === "some" && !imageFailed
    // True while any text on the card is cut short. "Show more" opens the
    // card, and an open card cuts nothing: the app name and the time and
    // origin wrap there instead.
    readonly property bool cut: appText.truncated || metaText.truncated
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
    readonly property var icon: NotificationIcons.choice(item)
    readonly property real textWidth: width - Theme.menuTextLeft - rightInset
    readonly property real actionMinWidth: PlatinumMetrics.buttonWidth(["Dismiss all", "Open"])

    onImageUrlChanged: imageFailed = false

    implicitHeight: content.implicitHeight + 16

    // A click on the body runs the app's default action when it has one.
    MouseArea {
        anchors.fill: parent
        cursorShape: card.hasDefault && card.item.sender_alive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: card.bodyClicked()
    }

    // An urgent item keeps a red edge, as its popup had.
    Rectangle {
        visible: card.critical
        x: 0
        y: 0
        width: 4
        height: parent.height
        color: Theme.menuDanger
    }

    // The keyboard's current card.
    Rectangle {
        visible: card.selected
        anchors.fill: parent
        anchors.margins: Theme.hair
        color: "transparent"
        border.width: 2 * Theme.hair
        border.color: Theme.highlight
    }

    // Etched rule between cards.
    Rectangle {
        visible: !card.lastRow
        anchors.bottom: parent.bottom
        x: Theme.menuTextLeft
        width: parent.width - x - card.rightInset
        height: Theme.hair
        color: Theme.bevelDark
    }

    Item {
        x: Theme.menuGutter
        y: 8
        width: Theme.menuGutterWidth
        height: Theme.menuGutterWidth

        IconImage {
            anchors.centerIn: parent
            visible: card.icon.kind === "image"
            source: card.icon.kind === "image" ? card.icon.url : ""
            implicitSize: 16
        }

        Bevel {
            anchors.fill: parent
            visible: card.icon.kind === "letter"
            Text {
                anchors.centerIn: parent
                text: card.icon.kind === "letter" ? card.icon.letter : ""
                color: Theme.menuText
                font.family: Theme.platinumFont
                font.pixelSize: Theme.platinumSmall
            }
        }
    }

    ColumnLayout {
        id: content
        x: Theme.menuTextLeft
        y: 8
        width: card.textWidth
        spacing: 3

        // App name, then when and where from, then dismiss. On an open
        // card the time and origin take a line of their own and both wrap.
        RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: 20
            spacing: Theme.menuGap

            Text {
                id: appText
                Layout.fillWidth: true
                text: Model.appLabel(card.item)
                textFormat: Text.PlainText
                wrapMode: card.expanded ? Text.Wrap : Text.NoWrap
                elide: card.expanded ? Text.ElideNone : Text.ElideRight
                color: Theme.menuTextSecondary
                font.family: Theme.platinumFont
                font.pixelSize: Theme.platinumSmall
                font.letterSpacing: Theme.platinumTracking
            }

            Text {
                id: metaText
                visible: card.meta !== "" && !card.expanded
                Layout.maximumWidth: card.textWidth * 0.5
                text: card.meta
                textFormat: Text.PlainText
                elide: Text.ElideLeft
                color: Theme.menuTextSecondary
                font.family: Theme.platinumFont
                font.pixelSize: Theme.platinumSmall
                font.letterSpacing: Theme.platinumTracking
            }

            Bevel {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                Layout.topMargin: 2
                sunken: dismissArea.pressed
                color: dismissArea.pressed ? Theme.well : Theme.raised

                PlatinumIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 8
                    color: Theme.menuText
                }

                MouseArea {
                    id: dismissArea
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: card.dismissRequested()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: card.expanded && card.meta !== ""
            text: card.meta
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Theme.menuTextSecondary
            font.family: Theme.platinumFont
            font.pixelSize: Theme.platinumSmall
            font.letterSpacing: Theme.platinumTracking
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.menuGap

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
                    maximumLineCount: card.expanded ? undefined : 2
                    elide: Text.ElideRight
                    color: card.low ? Theme.menuTextSecondary : Theme.menuText
                    font.family: Theme.platinumFont
                    font.pixelSize: Theme.platinumText
                    font.letterSpacing: Theme.platinumTracking
                }

                // Bodies are plain text: markup from an app or an agent is
                // not trusted.
                Text {
                    id: bodyText
                    Layout.fillWidth: true
                    visible: card.item.body !== ""
                    text: card.item.body
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: card.expanded ? undefined : card.bodyLines
                    elide: Text.ElideRight
                    color: Theme.menuTextSecondary
                    font.family: Theme.platinumFont
                    font.pixelSize: Theme.platinumSmall
                    font.letterSpacing: Theme.platinumTracking
                    lineHeight: 1.15
                }

                Text {
                    visible: card.expanded || card.cut
                    text: card.expanded ? "Show less" : "Show more"
                    color: Theme.menuText
                    font.family: Theme.platinumFont
                    font.pixelSize: Theme.platinumSmall
                    font.underline: true

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        onClicked: card.expandToggled()
                    }
                }
            }

            Rectangle {
                visible: card.hasImage
                Layout.preferredWidth: card.expanded ? 0 : 56
                Layout.preferredHeight: 56
                Layout.alignment: Qt.AlignTop
                color: Theme.well
                border.width: Theme.hair
                border.color: Theme.menuEdge

                Image {
                    anchors.fill: parent
                    anchors.margins: Theme.hair
                    source: card.hasImage && !card.expanded ? card.imageUrl : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 128
                    sourceSize.height: 128
                    onStatusChanged: if (status === Image.Error) card.imageFailed = true
                }
            }
        }

        // An open card shows the whole picture, at its own shape.
        Image {
            visible: card.hasImage && card.expanded
            Layout.fillWidth: true
            Layout.preferredHeight: implicitWidth > 0 ? Math.round(width * implicitHeight / implicitWidth) : 0
            source: card.hasImage && card.expanded ? card.imageUrl : ""
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 512
        }

        // Facts that change what the reader can expect.
        Flow {
            Layout.fillWidth: true
            visible: card.critical || card.localOnly !== ""
            spacing: 6

            Rectangle {
                visible: card.critical
                width: urgentText.implicitWidth + 12
                height: 18
                color: "transparent"
                border.width: Theme.hair
                border.color: Theme.menuDanger

                Text {
                    id: urgentText
                    anchors.centerIn: parent
                    text: "Urgent, stays until dismissed"
                    color: Theme.menuDanger
                    font.family: Theme.platinumFont
                    font.pixelSize: Theme.platinumHint
                }
            }

            Rectangle {
                visible: card.localOnly !== ""
                width: Math.min(localText.implicitWidth + 12, content.width)
                height: Math.max(18, localText.height + 4)
                color: "transparent"
                border.width: Theme.hair
                border.color: Theme.bevelDark

                Text {
                    id: localText
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 12
                    wrapMode: Text.Wrap
                    text: card.localOnly + ", not synced"
                    textFormat: Text.PlainText
                    color: Theme.menuTextSecondary
                    font.family: Theme.platinumFont
                    font.pixelSize: Theme.platinumHint
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !card.item.sender_alive && card.item.actions.length > 0
            text: "The app that sent this has closed. Its buttons no longer work."
            wrapMode: Text.Wrap
            color: Theme.menuWarning
            font.family: Theme.platinumFont
            font.pixelSize: Theme.platinumSmall
        }

        // Every action, in the app's order. A row that runs out of width
        // wraps; no action is ever dropped. Each is at least as wide as
        // the centre's own buttons, so short labels line up.
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 3
            visible: card.item.actions.length > 0
            spacing: 6

            Repeater {
                id: actionButtons
                model: card.item.actions

                PlatinumButton {
                    required property var modelData
                    required property int index
                    text: Model.buttonLabel(modelData)
                    keyHint: card.selected && index < 9 ? String(index + 1) : ""
                    fixedWidth: Math.min(content.width, Math.max(card.actionMinWidth,
                        PlatinumMetrics.buttonWidth([(keyHint !== "" ? keyHint + "  " : "") + text])))
                    focused: card.actionFocus.kind === "action" && card.actionFocus.index === index
                    enabled: card.item.sender_alive
                    onClicked: card.actionRequested(modelData.key)
                }
            }
        }
    }
}
