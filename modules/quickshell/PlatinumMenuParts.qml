import QtQuick
import QtQuick.Layouts

// Small pieces every bar menu shares. Use them as PlatinumMenuParts.Separator,
// PlatinumMenuParts.Section, PlatinumMenuParts.Hint, PlatinumMenuParts.Empty and PlatinumMenuParts.Line.
// Each starts on the menu's text edge and ends on its right edge.
QtObject {
    // An etched rule: dark over light, as Platinum draws a divider.
    component Separator: Item {
        Layout.fillWidth: true
        implicitHeight: 4 + 2 * PlatinumTokens.hair + 6

        Rectangle {
            x: PlatinumTokens.hair
            y: 4
            width: parent.width - 2 * PlatinumTokens.hair
            height: PlatinumTokens.hair
            color: PlatinumTokens.bevelDark
        }
        Rectangle {
            x: PlatinumTokens.hair
            y: 4 + PlatinumTokens.hair
            width: parent.width - 2 * PlatinumTokens.hair
            height: PlatinumTokens.hair
            color: PlatinumTokens.bevelLight
        }
    }

    // A section label, such as DEVICES or a host name.
    component Section: Text {
        property real rightInset: PlatinumTokens.menuRightInset
        Layout.fillWidth: true
        Layout.leftMargin: PlatinumTokens.menuTextLeft
        Layout.rightMargin: rightInset
        topPadding: 2
        bottomPadding: 4
        elide: Text.ElideRight
        textFormat: Text.PlainText
        color: PlatinumTokens.menuTextSecondary
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumSmall
        font.letterSpacing: PlatinumTokens.platinumTracking
    }

    // One line of plain text on the grid, with an optional colour.
    component Line: Text {
        property real rightInset: PlatinumTokens.menuRightInset
        Layout.fillWidth: true
        Layout.leftMargin: PlatinumTokens.menuTextLeft
        Layout.rightMargin: rightInset
        topPadding: 2
        bottomPadding: 2
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        color: PlatinumTokens.menuTextSecondary
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumSmall
        font.letterSpacing: PlatinumTokens.platinumTracking
        lineHeight: 1.15
    }

    // What an empty list says, and what to do about it.
    component Empty: Text {
        property real rightInset: PlatinumTokens.menuRightInset
        Layout.fillWidth: true
        Layout.leftMargin: PlatinumTokens.menuTextLeft
        Layout.rightMargin: rightInset
        topPadding: 12
        bottomPadding: 12
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        color: PlatinumTokens.menuTextSecondary
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumSmall
        font.letterSpacing: PlatinumTokens.platinumTracking
        lineHeight: 1.2
    }

    // A key hint. ChicagoFLF has no arrows, so ↑ ↓ ← → become SVG marks.
    // The hint wraps by word rather than cutting a key off.
    component Hint: Flow {
        id: hint
        property string text: ""
        property real rightInset: PlatinumTokens.menuRightInset
        // The space between words. A long hint that must hold one line
        // (the Layout menu's footer) passes the face's own space width.
        property real wordSpacing: 5
        readonly property var words: {
            const out = [];
            for (const part of hint.text.split(" ")) {
                if (part === "") continue;
                out.push(part);
            }
            return out;
        }
        Layout.fillWidth: true
        Layout.leftMargin: PlatinumTokens.menuTextLeft
        Layout.rightMargin: rightInset
        Layout.topMargin: 6
        spacing: 0

        Repeater {
            model: hint.words

            Row {
                id: word
                required property string modelData
                required property int index
                readonly property var pieces: modelData.split(/([↑↓←→])/).filter(function (p) { return p !== ""; })
                height: 16
                rightPadding: index < hint.words.length - 1 ? hint.wordSpacing : 0

                Repeater {
                    model: word.pieces

                    Item {
                        required property string modelData
                        readonly property bool arrow: "↑↓←→".indexOf(modelData) >= 0
                        width: arrow ? 11 : piece.implicitWidth
                        height: 16

                        Text {
                            id: piece
                            visible: !parent.arrow
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData
                            color: PlatinumTokens.menuTextSecondary
                            font.family: PlatinumTokens.platinumFont
                            font.pixelSize: PlatinumTokens.platinumHint
                            font.letterSpacing: PlatinumTokens.platinumTracking
                        }

                        PlatinumIcon {
                            visible: parent.arrow
                            anchors.centerIn: parent
                            name: "arrow"
                            width: 9
                            height: 10
                            color: PlatinumTokens.menuTextSecondary
                            rotation: ({"↑": 0, "→": 90, "↓": 180, "←": 270})[parent.modelData] || 0
                        }
                    }
                }
            }
        }
    }
}
