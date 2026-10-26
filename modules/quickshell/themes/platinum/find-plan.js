.pragma library
// Where the Find menu and the Go to Address dialog sit, and how big they
// are: a pure function of the screen's logical size (and, for the dialog,
// where the front window's title starts on the bar). PlatinumFindMenu and
// PlatinumGoToAddress read these; find-plan.test.js walks the sizes.
//
// Every threshold below is a guess until measured on Myoko, and each one is
// tested one pixel either side.

var BAR = 28;          // PlatinumTokens.barHeight
var EDGE = 6;          // the gap a menu keeps from the screen's edges
var MENU_MAX = 400;    // the Find menu's width when the screen has room
var MENU_MIN = 220;    // below this the menu is the screen's width less the edges
var POPUP_MIN = 260;   // the "All ⇕" pop-up shows from this menu width
var HINT_WIDE = 300;   // the hint column keeps 45% of a row from here
var HINT_MIN = 250;    // ...38% from here, and gives way below it

// The Find menu, hung from the mountain: its left edge on the mountain,
// its top on the bar's rule, never past the screen's right or bottom edge.
function menuPlan(W, H) {
    var room = Math.max(0, W - 2 * EDGE);
    var width = Math.min(MENU_MAX, room);
    if (width < MENU_MIN) width = room;
    return {
        x: EDGE,
        width: width,
        maxHeight: Math.max(0, H - BAR - EDGE),
        // Readouts (the hints) yield before labels: 45% of the row, then 38%,
        // then nothing. The hint text still matches a search.
        hintShare: width < HINT_MIN ? 0 : width < HINT_WIDE ? 0.38 : 0.45,
        // Too narrow for the pop-up: the scope shows as a text label in front of
        // the field, and Ctrl+1/2/3 and the "All Applications…" row still change it.
        popup: width >= POPUP_MIN
    };
}

var ADDR_MAX = 480;    // the dialog's width when the screen has room
var ADDR_MIN = 320;    // narrower than this under the title: the dialog takes the screen's width
var LIST_FIVE = 520;   // five page rows from this screen height
var LIST_THREE = 400;  // three from here; none below (the field and the buttons stay)
var HOST_COLUMN = 420; // the page list shows each page's host from this dialog width

// The Go to Address dialog: under the bar, its left edge on the front
// window's title (what it acts on), not centred.
function addrPlan(W, H, titleX) {
    var x = Math.max(EDGE, titleX || 0);
    var width = Math.min(ADDR_MAX, W - x - EDGE);
    if (width < ADDR_MIN) {
        x = EDGE;
        width = Math.min(ADDR_MAX, Math.max(0, W - 2 * EDGE));
    }
    var listRows = H >= LIST_FIVE ? 5 : H >= LIST_THREE ? 3 : 0;
    return {
        x: x, y: BAR + 4, width: width, listRows: listRows,
        hostColumn: width >= HOST_COLUMN,
        maxHeight: Math.max(0, H - BAR - 4 - EDGE),
        // The buttons stack when two side by side do not fit.
        stackButtons: width < 200
    };
}
