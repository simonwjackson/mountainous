.pragma library
// Win98Tabs in one row (the Fleet Properties sheet), as a pure function.
// A Properties sheet's tabs stay in one row. When they do not fit, the row
// scrolls, as a Win98 tab control without TCS_MULTILINE did: an up-down
// control (two 16-u arrows) at the right moves the first tab shown, and the
// current tab is always shown. widths: each tab's width (its label plus
// 14 u); room: the strip's width. Tabs overlap by 1 u and the row starts
// and ends 2 u in.
var UPDOWN = 32;
function rowWidth(widths, from, to) {
    var s = 4;
    for (var i = from; i <= to; i++) s += widths[i] - (i > from ? 1 : 0);
    return s;
}
function tabStrip(widths, room, current, first) {
    var n = widths.length;
    if (n === 0) return {mode: "row", first: 0, last: -1, left: false, right: false};
    if (rowWidth(widths, 0, n - 1) <= room + 1e-9) return {mode: "row", first: 0, last: n - 1, left: false, right: false};
    var avail = room - UPDOWN;
    var cur = Math.max(0, Math.min(n - 1, current));
    var f = Math.max(0, Math.min(n - 1, first || 0));
    if (cur < f) f = cur;
    var lastFrom = function (from) {
        var l = from;
        while (l + 1 < n && rowWidth(widths, from, l + 1) <= avail + 1e-9) l++;
        return l;
    };
    var last = lastFrom(f);
    while (cur > last && f < cur) { f++; last = lastFrom(f); }
    return {mode: "scroll", first: f, last: last, left: f > 0, right: last < n - 1};
}

