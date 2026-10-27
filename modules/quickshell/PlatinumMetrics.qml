pragma Singleton

import Quickshell
import QtQuick

// Text widths in ChicagoFLF, for the fixed boxes the bar and the menus
// draw. ChicagoFLF has no tabular digits, so a number sits in a box as
// wide as its widest value, and a button role takes its longest label's
// width. Both come from here.
Singleton {
    id: root

    FontMetrics {
        id: text
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumText
        font.letterSpacing: PlatinumTokens.platinumTracking
    }

    FontMetrics {
        id: small
        font.family: PlatinumTokens.platinumFont
        font.pixelSize: PlatinumTokens.platinumSmall
        font.letterSpacing: PlatinumTokens.platinumTracking
    }

    // Whole even logical pixels: at scale 1.5 an even width ends on a
    // whole physical pixel.
    function even(v) { return Math.ceil(v / 2 - 1e-6) * 2; }

    function width(s) { return Math.ceil(text.advanceWidth(s)); }
    function smallWidth(s) { return Math.ceil(small.advanceWidth(s)); }

    // The widest of several strings, so 9, 42 and 100 take one width.
    function widest(strings) {
        let w = 0;
        for (const s of strings) w = Math.max(w, text.advanceWidth(s));
        return Math.ceil(w) + 1;
    }

    function smallWidest(strings) {
        let w = 0;
        for (const s of strings) w = Math.max(w, small.advanceWidth(s));
        return Math.ceil(w) + 1;
    }

    // A button role's width: its longest label plus the face's padding.
    function buttonWidth(labels) {
        return root.even(root.smallWidest(labels) + 20);
    }

    // The widest digit, so a box for "100" holds any three digits.
    readonly property string wideDigit: {
        let best = "0", bestW = 0;
        for (let d = 0; d <= 9; d++) {
            const w = text.advanceWidth(String(d));
            if (w > bestW) { bestW = w; best = String(d); }
        }
        return best;
    }
    function digits(n) { return root.wideDigit.repeat(n); }

    // A box for a number as it stands, each digit at the widest digit's
    // width: "1" and "7" take one width, "12" and "99" another. The
    // value does not move while its digit count holds, and a short number
    // leaves no empty box sized for three digits beside its word.
    function digitBox(s) {
        return root.widest([String(s).replace(/[0-9]/g, root.wideDigit)]);
    }
}
