import QtQuick
import "builder-gate.js" as Gate

// The remote-builder gate on the Platinum bar: a title like every other.
// A press, or a right-click, opens its menu (BuilderPanel), and the menus
// follow the pointer onto it. The flip itself is the menu's first row,
// "Accept builds" (T).
//
// The hammer is the state: whole while myoko accepts, struck through
// while it refuses, grey when the default rule refuses. A dot on the
// hammer says builds are running. Words come onto the bar only while an
// action failed (the warning tone); they are a readout and yield first.
// The full state ("On by you", "Building 2") is in Balloon Help and in
// the menu's header.
PlatinumBarControl {
    id: root

    required property var gate
    property bool showLabel: true

    readonly property var sample: gate ? gate.sample : Gate.loading()
    readonly property string pending: gate ? gate.pending : ""
    readonly property var actionError: gate ? gate.actionError : null
    readonly property string gateTone: Gate.tone(sample, pending, actionError)
    readonly property int running: sample.kind === "ready" ? sample.value.running : 0

    menu: "builder"
    icon: "builder"
    slashed: Gate.mark(sample, pending) === "off"
    tone: PlatinumTokens.barTone(gateTone === "warning" ? "warning" : gateTone === "muted" ? "muted" : "normal")

    // The bar's words: the full state for Balloon Help and », and the
    // warning words the bar shows while an action failed.
    readonly property string fullText: Gate.barText(sample, pending, actionError, "wide")
    readonly property string warnText: gateTone === "warning" ? fullText : ""
    readonly property real fullWidth: warnText === "" ? 0 : PlatinumMetrics.width(warnText)

    Text {
        visible: root.showLabel && root.warnText !== ""
        text: root.warnText
        textFormat: Text.PlainText
        color: root.fg
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumText
        font.letterSpacing: PlatinumTokens.platinumTracking
    }

    // Builds are running: the badge the bell uses, on the hammer's head.
    iconExtras: PlatinumBarBadge {
        visible: root.running > 0
        fill: root.fg
        knock: root.bg
    }
}
