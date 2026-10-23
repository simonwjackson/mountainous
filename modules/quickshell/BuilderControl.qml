import QtQuick
import "builder-gate.js" as Gate

// The remote-builder gate on the Platinum bar: a title like every other.
// A press, or a right-click, opens its menu (BuilderPanel), and the menus
// follow the pointer onto it. The flip itself is the menu's first row,
// "Accept builds" (T).
//
// At rest the title still says the state at a glance: the hammer while
// myoko accepts, the hammer struck through while it refuses, in the gate's
// tone (grey when the default rule refuses, the text colour when you
// chose it). The words say when the choice is yours ("On by you"), so the
// title draws no outline for it.
//
// The words ("Builds off: battery", "Building 2") are a readout and yield
// to the count alone, which stays in its own box.
BarControl {
    id: root

    required property var gate
    property bool showLabel: true

    readonly property var sample: gate ? gate.sample : Gate.loading()
    readonly property string pending: gate ? gate.pending : ""
    readonly property var actionError: gate ? gate.actionError : null

    menu: "builder"
    icon: "builder"
    slashed: Gate.mark(sample, pending) === "off"
    tone: Theme.barTone(Gate.tone(sample, pending, actionError))

    // What the plan measures: the full words and the compact count. A
    // count sits in a box as wide as two wide digits, so "Building 2" and
    // "Building 12" take one width and the bar does not move.
    readonly property string fullText: Gate.barText(sample, pending, actionError, "wide")
    readonly property string compactText: Gate.barText(sample, pending, actionError, "tiny")
    function boxWidth(text) {
        if (text === "") return 0;
        return PlatinumMetrics.widest([text.replace(/\d+/g, function (m) {
            return PlatinumMetrics.digits(Math.max(2, m.length));
        })]);
    }
    readonly property real fullWidth: boxWidth(fullText)
    readonly property real compactWidth: Math.min(boxWidth(compactText), fullWidth)

    Text {
        visible: text !== ""
        width: root.showLabel ? root.fullWidth : root.compactWidth
        text: root.showLabel ? root.fullText : root.compactText
        textFormat: Text.PlainText
        color: root.fg
        font.family: Theme.platinumFont
        font.pixelSize: Theme.platinumText
        font.letterSpacing: Theme.platinumTracking
    }
}
