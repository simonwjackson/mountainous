.pragma library
// The Win98 Find window (Super+P) and Internet Explorer's Open dialog
// (Ctrl+L): their structure and place, a pure function of the room above
// the taskbar. Every size is in Win98 units (u, Win98Tokens.unitFor), so
// the plan is the same at every scale. Win98FindWindow and Win98OpenDialog
// read it; find-plan.test.js walks the sizes. Ported from the approved
// mock's findPlan and addrPlan (/tmp/tandem/win98-parity-mock/features.js).
//
// Every threshold is a guess until measured on Myoko, and each one is
// tested one unit either side.

var EDGE = 2;          // the gap a window keeps from the screen's edges and the taskbar
var FRAME = 3;         // Win98Tokens.frame
var CAPTION = 18;      // Win98Tokens.captionHeight
var BUTTON = 23;       // Win98Tokens.buttonHeight
var FIELD = 21;        // Win98Tokens.fieldHeight
var ROW = 16;          // a list row
var HEAD = 16;         // a group row (bold label and an etched rule)
var SEP = 8;           // a separator row
var COLUMN_HEADER = 17;
var STATUS = 18;       // Win98StatusBar, one line

var FIND = {
    WIDTH: 400,        // the window's width when the screen has room
    BUTTON_COLUMN: 300, // Open and Close stand right of the criteria from here; below, in a row under the list
    INLINE: 520,       // a short, wide screen puts Named, Look in, Open and Close on one row,
                       // the window this wide (it spends the plentiful axis)
    DETAIL: 300,       // the Details column takes 36% of the list from here
    DETAIL_NARROW: 200, // ...30% from here; below, it goes (the status bar still shows it)
    ROWS_MAX: 18,      // the list's rows when the screen has room (it keeps this height while you type)
    ROWS_SHORT: 6,     // a short screen gives up rows down to this first
    ROWS_MIN: 3        // ...and down to this after the status bar and the second criteria row went
};

// The Find window. W, H: the room above the taskbar, in u.
//   width, height  the window
//   x, y           its top left, above the Start button
//   buttonColumn   Open and Close beside the criteria (else a row under the list)
//   detail         the Details column's share of the list (0: no column)
//   status         the status bar shows (else the count goes into the caption)
//   inline         Named, Look in, Open and Close share one row (a wider window)
//   list           the list's rows area, in u (whole rows of 16 u)
//   natural        the height the window needs; scroll when it is over height
//   steps          what gave way, in order
function findPlan(W, H) {
    var width = Math.max(0, Math.min(FIND.WIDTH, W - 2 * EDGE));
    var room = Math.max(0, H - 2 * EDGE);
    var buttonColumn = width >= FIND.BUTTON_COLUMN;
    var detail = width >= FIND.DETAIL ? 0.36 : width >= FIND.DETAIL_NARROW ? 0.3 : 0;
    // The caption and frame, and 6 u of padding inside the body, top and bottom.
    var chrome = 2 * FRAME + CAPTION + 1 + 12;
    var buttonRow = buttonColumn ? 0 : BUTTON + 6;
    // The list's well: 2 u edges, the column header.
    var listFrame = 4 + COLUMN_HEADER;
    var statusBar = STATUS + 2 + 6;
    function h(criteria, list, status) { return chrome + criteria + 6 + listFrame + list + status + buttonRow; }
    // Named and Look in: two rows, each as tall as the button beside it
    // when Open and Close stand at the right (the fields centre in them).
    var criteria = buttonColumn ? 2 * BUTTON + 4 : 2 * FIELD + 4, status = statusBar, inline = false;
    var list = ROW * FIND.ROWS_MAX;
    var steps = [];
    function whole(px) { return Math.max(0, Math.floor(px / ROW) * ROW); }
    if (h(criteria, list, status) > room) {
        list = Math.max(ROW * FIND.ROWS_SHORT, whole(room - h(criteria, 0, status)));
        steps.push("list rows");
    }
    if (h(criteria, list, status) > room) { status = 0; steps.push("status bar to caption"); }
    if (h(criteria, list, status) > room && W - 2 * EDGE >= FIND.INLINE) {
        criteria = BUTTON; inline = true; width = FIND.INLINE; steps.push("criteria on one row");
    }
    if (h(criteria, list, status) > room) {
        list = Math.max(ROW * FIND.ROWS_MIN, whole(room - h(criteria, 0, status)));
        steps.push("list rows");
    }
    var natural = h(criteria, list, status);
    var height = Math.min(natural, room);
    if (natural > room) steps.push("body scrolls");
    return {
        width: width, height: height, natural: natural, criteria: criteria,
        x: EDGE, y: Math.max(EDGE, H - EDGE - height),
        buttonColumn: buttonColumn, detail: detail, status: status > 0, inline: inline,
        list: list, scroll: natural > room, steps: steps
    };
}

var OPEN = {
    WIDTH: 340,        // the dialog's width when the screen has room
    LABEL_ABOVE: 230,  // narrower: "Open:" stands above the field
    LIST_ROWS: 8       // the drop-down's rows before it scrolls
};

// Internet Explorer's Open dialog. W, H: the room above the taskbar, in u;
// caller: the caller window's rectangle in u ({x, y, w, h}) or null.
//   width, height, x, y   the dialog, centred on the caller (else on the room)
//   labelAbove            "Open:" above the field
//   intro                 the globe and the line under the caption show
//   natural, scroll       as findPlan
function openPlan(W, H, caller) {
    var width = Math.max(0, Math.min(OPEN.WIDTH, W - 2 * EDGE));
    var room = Math.max(0, H - 2 * EDGE);
    var labelAbove = width < OPEN.LABEL_ABOVE;
    var chrome = 2 * FRAME + CAPTION + 1 + 16;
    var intro = 34 + 8, field = (labelAbove ? 15 : 0) + FIELD + 6, dest = 28 + 8, buttons = BUTTON;
    var showIntro = true;
    var natural = chrome + intro + field + dest + buttons;
    var steps = [];
    if (natural > room) { showIntro = false; natural -= intro; steps.push("intro"); }
    var height = Math.min(natural, room);
    if (natural > room) steps.push("body scrolls");
    var cx = caller ? caller.x + caller.w / 2 : W / 2;
    var cy = caller ? caller.y + caller.h / 2 : H / 2;
    var x = Math.round(cx - width / 2), y = Math.round(cy - height / 2);
    x = Math.max(EDGE, Math.min(x, W - EDGE - width));
    y = Math.max(EDGE, Math.min(y, H - EDGE - height));
    return {
        width: width, height: height, natural: natural, x: x, y: y,
        labelAbove: labelAbove, intro: showIntro, scroll: natural > room,
        listRows: OPEN.LIST_ROWS, steps: steps
    };
}

// A drop-down list under (or, without room below, over) its field, inside
// the room. field: {x, y, w, h} in u; rows: how many it lists; minWidth.
function dropPlan(W, H, field, rows, minWidth) {
    var height = Math.max(1, rows) * ROW + 4;
    var width = Math.min(W - 2 * EDGE, Math.max(field.w, minWidth || 0));
    var x = Math.max(EDGE, Math.min(field.x, W - EDGE - width));
    var below = H - EDGE - (field.y + field.h);
    var above = field.y - EDGE;
    var up = below < height && above > below;
    var room = up ? above : below;
    var shown = Math.min(height, Math.max(ROW + 4, Math.floor((room - 4) / ROW) * ROW + 4));
    return { x: x, y: up ? field.y - shown : field.y + field.h, width: width, height: shown, up: up,
             scrolls: shown < height };
}

// The rows' heights, for the list's scroll arithmetic.
function rowHeight(r) { return !r ? 0 : r.t === "head" ? HEAD : r.t === "sep" ? SEP : ROW; }
function rowTop(rows, index) {
    var y = 0;
    for (var i = 0; i < index && i < rows.length; i++) y += rowHeight(rows[i]);
    return y;
}
function contentHeight(rows) { return rowTop(rows, rows.length); }
// The scroll offset that keeps row `index` whole in a view `view` u tall.
// The first selectable row starts the list unscrolled.
function scrollFor(rows, index, scroll, view, first) {
    var max = Math.max(0, contentHeight(rows) - view);
    if (index < 0) return Math.max(0, Math.min(scroll, max));
    if (index === first) return 0;
    var top = rowTop(rows, index), bottom = top + rowHeight(rows[index]);
    var s = Math.max(0, Math.min(scroll, max));
    if (top < s) s = top;
    if (bottom > s + view) s = bottom - view;
    return Math.max(0, Math.min(s, max));
}
// The row under a point `y` u down the rows area, or -1.
function rowAt(rows, y) {
    var top = 0;
    for (var i = 0; i < rows.length; i++) {
        var h = rowHeight(rows[i]);
        if (y >= top && y < top + h) return i;
        top += h;
    }
    return -1;
}

// What the status bar says about the chosen row.
var KIND_WORDS = { win: "Window", app: "Application", recent: "Recent application", cmd: "Command",
                   scope: "Search", addr: "Go to address", none: "" };
function status(rows, index) {
    var items = 0;
    for (var i = 0; i < rows.length; i++) if (rows[i].t === "item" && !rows[i].dis) items++;
    var r = rows[index];
    var detail = r && r.t === "item" && !r.dis ? KIND_WORDS[r.k] + (r.hint ? ": " + r.hint : "") : "";
    return { count: items + (items === 1 ? " item" : " items"), items: items, detail: detail };
}
