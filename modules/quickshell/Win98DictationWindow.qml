import QtQuick

// Dictation as a Win98 window: what the recorder is doing, and Retry and
// Dismiss after a failure (Retry only when a take can be sent again). The
// shared Dictation owns the takes; the bottom-centre overlay is unchanged.
Win98Window {
    id: root

    required property var dictation
    required property string text

    readonly property bool failed: dictation.state === "failed"
    title: "Dictation"
    iconName: "mic-recording"
    onCloseClicked: MenuState.close()

    Column {
        width: root.width - 22 * root.u
        spacing: 6 * root.u

        Row {
            spacing: 6 * root.u
            Win98Icon { name: root.failed ? "mic-failed" : root.dictation.state === "working" ? "mic-working" : "mic-recording" }
            Win98Text {
                y: Win98Tokens.snap((16 * root.u - height) / 2, root.u)
                text: root.text
                accessMarks: false
                bold: true
                color: root.failed ? Win98Tokens.danger : Win98Tokens.text
            }
        }
        Item {
            visible: root.failed
            width: parent.width
            height: visible ? 23 * root.u : 0
            Row {
                x: parent.width - width
                spacing: 6 * root.u
                Win98Button {
                    id: retry
                    visible: root.dictation.canRetry
                    text: "&Retry"
                    isDefault: true
                    focus: visible
                    onClicked: { MenuState.close(); root.dictation.retryFailed(); }
                }
                Win98Button {
                    id: dismiss
                    text: "&Dismiss"
                    isDefault: !root.dictation.canRetry
                    focus: !root.dictation.canRetry
                    onClicked: { MenuState.close(); root.dictation.dismissFailure(); }
                }
            }
        }
        Win98Text {
            visible: !root.failed
            width: parent.width
            wrap: true
            text: "The overlay at the bottom centre shows the take."
            accessMarks: false
            color: Win98Tokens.gray
        }
    }

    Shortcut { sequence: "R"; context: Qt.WindowShortcut; enabled: root.failed && root.dictation.canRetry; onActivated: retry.clicked() }
    Shortcut { sequence: "D"; context: Qt.WindowShortcut; enabled: root.failed; onActivated: dismiss.clicked() }
}
