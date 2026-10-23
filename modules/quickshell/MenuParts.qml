import QtQuick
import QtQuick.Layouts

// Small pieces every bar menu shares. Use them as MenuParts.Separator,
// MenuParts.Section, MenuParts.Hint, MenuParts.Empty and MenuParts.Line.
// Each starts on the menu's text edge and ends on its right edge.
QtObject {
    // An etched rule: dark over light, as Platinum draws a divider.
    component Separator: Item {
        Layout.fillWidth: true
        implicitHeight: 4 + 2 * Theme.hair + 6

        Rectangle {
            x: Theme.hair
            y: 4
            width: parent.width - 2 * Theme.hair
            height: Theme.hair
            color: Theme.bevelDark
        }
        Rectangle {
            x: Theme.hair
            y: 4 + Theme.hair
            width: parent.width - 2 * Theme.hair
            height: Theme.hair
            color: Theme.bevelLight
        }
    }

    // A section label, such as DEVICES or a host name.
    component Section: Text {
        property real rightInset: Theme.menuRightInset
        Layout.fillWidth: true
        Layout.leftMargin: Theme.menuTextLeft
        Layout.rightMargin: rightInset
        topPadding: 2
        bottomPadding: 4
        elide: Text.ElideRight
        textFormat: Text.PlainText
        color: Theme.menuTextSecondary
        font.family: Theme.platinumFont
        font.pixelSize: Theme.platinumSmall
        font.letterSpacing: Theme.platinumTracking
    }

    // One line of plain text on the grid, with an optional colour.
    component Line: Text {
        property real rightInset: Theme.menuRightInset
        Layout.fillWidth: true
        Layout.leftMargin: Theme.menuTextLeft
        Layout.rightMargin: rightInset
        topPadding: 2
        bottomPadding: 2
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        color: Theme.menuTextSecondary
        font.family: Theme.platinumFont
        font.pixelSize: Theme.platinumSmall
        font.letterSpacing: Theme.platinumTracking
        lineHeight: 1.15
    }

    // What an empty list says, and what to do about it.
    component Empty: Text {
        property real rightInset: Theme.menuRightInset
        Layout.fillWidth: true
        Layout.leftMargin: Theme.menuTextLeft
        Layout.rightMargin: rightInset
        topPadding: 12
        bottomPadding: 12
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        color: Theme.menuTextSecondary
        font.family: Theme.platinumFont
        font.pixelSize: Theme.platinumSmall
        font.letterSpacing: Theme.platinumTracking
        lineHeight: 1.2
    }

    // A key hint. ChicagoFLF has no arrows, so ↑ ↓ ← → become SVG marks.
    // The hint wraps by word rather than cutting a key off.
    component Hint: Flow {
        id: hint
        property string text: ""
        property real rightInset: Theme.menuRightInset
        readonly property var words: {
            const out = [];
            for (const part of hint.text.split(" ")) {
                if (part === "") continue;
                out.push(part);
            }
            return out;
        }
        Layout.fillWidth: true
        Layout.leftMargin: Theme.menuTextLeft
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
                rightPadding: index < hint.words.length - 1 ? 5 : 0

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
                            color: Theme.menuTextSecondary
                            font.family: Theme.platinumFont
                            font.pixelSize: Theme.platinumHint
                            font.letterSpacing: Theme.platinumTracking
                        }

                        PlatinumIcon {
                            visible: parent.arrow
                            anchors.centerIn: parent
                            name: "arrow"
                            width: 9
                            height: 10
                            color: Theme.menuTextSecondary
                            rotation: ({"↑": 0, "→": 90, "↓": 180, "←": 270})[parent.modelData] || 0
                        }
                    }
                }
            }
        }
    }
}
