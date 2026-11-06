.pragma library
// Display Properties (MemphisPickerView): how far its body and sheet sit
// inside the dialog, as a pure function of the dialog's width in Memphis
// units (u). Spacing yields before content: a narrow dialog keeps the room
// for the scheme names. picker-plan.test.js tests the threshold one unit
// either side.
//
// The threshold is a guess until measured on Myoko.

var COMPACT_WIDTH = 200;              // below this the insets shrink
var WIDE = { body: 6, sheet: 8 };     // the body inside the frame, the sheet inside the tab
var COMPACT = { body: 2, sheet: 3 };

function insets(dialogWidth) {
    var compact = dialogWidth < COMPACT_WIDTH;
    var i = compact ? COMPACT : WIDE;
    return { compact: compact, body: i.body, sheet: i.sheet };
}
