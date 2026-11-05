.pragma library
// The Memphis drop-down list (MemphisComboBox): the closed field's structure
// and the open list's width, place and scrolling, as pure functions of the
// room the window gives. Every size is in Memphis units (u); the component
// multiplies by its unit. combo-plan.test.js walks each threshold one unit
// either side.
//
// Every threshold is a guess until measured on Myoko.

var BUTTON = 16;      // the arrow button's width
var INSET = 3;        // the value box's inset from the field's left edge
var GAP = 2;          // value box to the button
var VALUE_MIN = 24;   // the narrowest value box worth a line beside the button
var LINE = 13;        // the font's line pitch (MemphisTokens.lineUnits)
var ROW = 17;         // one single-line row of the open list
var MAX_ROWS = 10;    // the list shows this many single-line rows, then scrolls
var EDGE = 1;         // the list's black edge
var PAD = 8;          // a row's text inset, both sides together
var SCROLLBAR = 16;   // MemphisTokens.scrollBar

// The closed field at width w. Inline: the value box, then the button on
// the same line (Memphis). Stacked, when the value box would be narrower than
// VALUE_MIN: the value box takes the whole width and wraps, and the button
// sits on its own line under it, at the right. valueLines is how many lines
// the value's text needs at valueWidth (the component measures it).
function field(w, valueLines) {
    var lines = Math.max(1, valueLines || 1);
    var inlineWidth = w - INSET - GAP - BUTTON - 2;
    var stacked = inlineWidth < VALUE_MIN;
    var valueWidth = Math.max(0, stacked ? w - 2 * INSET : inlineWidth);
    // One line is Memphis's 15-u value box; each further line adds a line.
    var valueHeight = lines * LINE + 2;
    var height = stacked ? INSET + valueHeight + 2 + 17 + 2 : Math.max(21, INSET + valueHeight + INSET);
    return {
        stacked: stacked,
        valueWidth: valueWidth,
        valueHeight: valueHeight,
        height: height,
        buttonX: w - 2 - BUTTON,
        buttonY: stacked ? INSET + valueHeight + 2 : 2
    };
}

// The open list's width: at least the field's, as wide as its longest
// label and its scroll bar need, never wider than the window. Labels wrap
// inside it when the window is narrower than the longest one.
function listWidth(fieldWidth, widestLabel, hostWidth, scrolls) {
    var want = Math.ceil(widestLabel) + PAD + 2 * EDGE + (scrolls ? SCROLLBAR : 0);
    return Math.max(0, Math.min(hostWidth, Math.max(fieldWidth, want)));
}

// The text width a row has inside a list of width w.
function rowTextWidth(w, scrolls) {
    return Math.max(1, w - 2 * EDGE - PAD - (scrolls ? SCROLLBAR : 0));
}

// The top of row i, from the rows' heights.
function rowTop(rows, i) {
    var y = 0;
    for (var k = 0; k < i && k < rows.length; k++) y += rows[k];
    return y;
}
function total(rows) { return rowTop(rows, rows.length); }

// Where the open list goes. o: { rows (heights), fieldTop, fieldBottom,
// area (the usable height: the window less any strip at its foot),
// maxRows (optional, default MAX_ROWS) }.
// Returns { mode: "down" | "up" | "over", y (the list's top edge), view
// (the rows' viewport height), height (with the edges), scrolls }.
//   - down when the wanted height fits below the field;
//   - else up when there is more room above than below;
//   - else down, shortened to the room;
//   - over when not even the shortest row fits above or below: the list
//     lies over the field, inside the usable height.
// The wanted height is every row, up to MAX_ROWS single-line rows' worth.
// A shortened view may cut a row: the cut row and the scroll bar show
// that more exists.
function place(o) {
    var rows = o.rows || [];
    var content = total(rows);
    var want = Math.min(content, (o.maxRows || MAX_ROWS) * ROW);
    var shortest = rows.length ? Math.min.apply(null, rows) : ROW;
    var below = Math.max(0, o.area - o.fieldBottom - 2 * EDGE);
    var above = Math.max(0, o.fieldTop - 2 * EDGE);
    var mode, view, y;
    if (below >= want) { mode = "down"; view = want; }
    else if (below < shortest && above < shortest) { mode = "over"; view = Math.min(want, Math.max(0, o.area - 2 * EDGE)); }
    else if (above > below) { mode = "up"; view = Math.min(want, above); }
    else { mode = "down"; view = Math.min(want, below); }
    var height = view + 2 * EDGE;
    if (mode === "down") y = o.fieldBottom;
    else if (mode === "up") y = o.fieldTop - height;
    else y = Math.max(0, Math.min(o.fieldTop, o.area - height));
    return { mode: mode, y: y, view: view, height: height, scrolls: view < content };
}

// The scroll offset that shows row i whole (its top, if it is taller than
// the view), moving as little as it can from contentY.
function reveal(rows, i, contentY, view) {
    if (i < 0 || i >= rows.length) return contentY;
    var top = rowTop(rows, i), bottom = top + rows[i];
    var max = Math.max(0, total(rows) - view);
    var y = contentY;
    if (top < y || rows[i] > view) y = top;
    else if (bottom > y + view) y = bottom - view;
    return Math.max(0, Math.min(max, y));
}

// Page Up / Page Down: from row i, the furthest row in direction dir
// whose rows, i included, still fit in one view; at least one row.
function page(rows, i, view, dir) {
    var n = rows.length;
    if (!n) return -1;
    var start = Math.max(0, Math.min(n - 1, i)), j = start, sum = rows[start];
    while (true) {
        var next = j + dir;
        if (next < 0 || next >= n || sum + rows[next] > view) break;
        sum += rows[next];
        j = next;
    }
    if (j === start && start + dir >= 0 && start + dir < n) j = start + dir;
    return j;
}
