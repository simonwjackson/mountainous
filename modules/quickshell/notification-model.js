.pragma library
// The notification view's pure half: socket lines in, view state out, and the
// layout plans. No QML types here, so notification-model.test.js runs the same
// file under node. The protocol is contract section 7; nothing here adds a
// field the daemon does not send.

// ---------------------------------------------------------------- protocol

const URGENCY_LOW = 0;
const URGENCY_NORMAL = 1;
const URGENCY_CRITICAL = 2;

function emptyStatus() {
    return {server: "connecting", outbox: 0, last_error: null};
}

function str(value) {
    return typeof value === "string" ? value : "";
}

function num(value, fallback) {
    return typeof value === "number" && isFinite(value) ? value : fallback;
}

// A daemon item, with every field coerced to the type the view reads. An item
// without a numeric id cannot be dismissed, so it is dropped as malformed.
function normaliseItem(raw) {
    if (!raw || typeof raw !== "object" || typeof raw.id !== "number" || !isFinite(raw.id)) return null;
    const actions = Array.isArray(raw.actions) ? raw.actions.filter(function (a) {
        return a && typeof a.key === "string" && a.key !== "";
    }).map(function (a) {
        return {key: a.key, label: str(a.label)};
    }) : [];
    const urgency = num(raw.urgency, URGENCY_NORMAL);
    return {
        id: raw.id,
        seq: str(raw.seq),
        origin: raw.origin === "remote" ? "remote" : "local",
        host: str(raw.host),
        app_name: str(raw.app_name),
        app_icon: str(raw.app_icon),
        image: typeof raw.image === "string" && raw.image !== "" ? raw.image : null,
        summary: str(raw.summary),
        body: str(raw.body),
        actions: actions,
        urgency: urgency <= URGENCY_LOW ? URGENCY_LOW : urgency >= URGENCY_CRITICAL ? URGENCY_CRITICAL : URGENCY_NORMAL,
        resident: raw.resident === true,
        local_only: raw.local_only === true,
        created: num(raw.created, 0),
        updated: num(raw.updated, num(raw.created, 0)),
        // Missing means the daemon did not say the sender is gone.
        sender_alive: raw.sender_alive !== false
    };
}

function normaliseStatus(raw) {
    if (!raw || typeof raw !== "object") return emptyStatus();
    const server = ["connected", "connecting", "unreachable"].indexOf(raw.server) >= 0
        ? raw.server : "connecting";
    return {
        server: server,
        outbox: Math.max(0, Math.floor(num(raw.outbox, 0))),
        last_error: typeof raw.last_error === "string" && raw.last_error !== "" ? raw.last_error : null
    };
}

function eventOf(event) { return {kind: "event", event: event}; }
function invalid(reason) { return {kind: "invalid", reason: reason}; }

// One socket line to {kind: "event", event} or {kind: "invalid", reason}.
function parseLine(line) {
    let value;
    try {
        value = JSON.parse(line);
    } catch (e) {
        return invalid("not JSON");
    }
    if (!value || typeof value !== "object" || Array.isArray(value)) return invalid("not an object");
    if (value.type === "snapshot") {
        const items = Array.isArray(value.items) ? value.items.map(normaliseItem).filter(Boolean) : [];
        return eventOf({type: "snapshot", items: items, status: normaliseStatus(value.status)});
    }
    if (value.type === "upsert") {
        const item = normaliseItem(value.item);
        return item ? eventOf({type: "upsert", item: item, fresh: value.fresh === true}) : invalid("item without an id");
    }
    if (value.type === "remove") {
        return typeof value.id === "number"
            ? eventOf({type: "remove", id: value.id, reason: num(value.reason, 0)})
            : invalid("remove without an id");
    }
    if (value.type === "status") {
        return eventOf({type: "status", status: normaliseStatus(value.status)});
    }
    return invalid("unknown type");
}

// Fold one event into {items, status, popups}. popups lists the ids that show
// a popup, newest first. The result is a new object; the input is not changed.
function applyEvent(state, event) {
    if (event.type === "snapshot") {
        // A snapshot is the whole truth. Popups for items that survived it
        // stay; a snapshot never starts a popup.
        const ids = event.items.map(function (i) { return i.id; });
        return {
            items: sortItems(event.items),
            status: event.status,
            popups: state.popups.filter(function (id) { return ids.indexOf(id) >= 0; })
        };
    }
    if (event.type === "upsert") {
        const others = state.items.filter(function (i) { return i.id !== event.item.id; });
        let popups = state.popups;
        if (event.fresh) {
            popups = [event.item.id].concat(popups.filter(function (id) { return id !== event.item.id; }));
        }
        return {items: sortItems(others.concat([event.item])), status: state.status, popups: popups};
    }
    if (event.type === "remove") {
        return {
            items: state.items.filter(function (i) { return i.id !== event.id; }),
            status: state.status,
            popups: state.popups.filter(function (id) { return id !== event.id; })
        };
    }
    if (event.type === "status") {
        return {items: state.items, status: event.status, popups: state.popups};
    }
    return state;
}

function initialState() {
    return {items: [], status: emptyStatus(), popups: []};
}

// Critical first, then newest change first. The id breaks ties so the order
// never flickers between two equal timestamps.
function sortItems(items) {
    const list = items.slice();
    list.sort(function (a, b) {
        const ca = a.urgency === URGENCY_CRITICAL ? 1 : 0;
        const cb = b.urgency === URGENCY_CRITICAL ? 1 : 0;
        if (ca !== cb) return cb - ca;
        if (a.updated !== b.updated) return b.updated - a.updated;
        return b.id - a.id;
    });
    return list;
}

// ---------------------------------------------------------------- selections
//
// Every lookup returns a tagged value, never null: {kind: "some", value} or
// {kind: "none"}.

function some(value) { return {kind: "some", value: value}; }
function none() { return {kind: "none"}; }

function findItem(items, id) {
    for (let i = 0; i < items.length; i++) {
        if (items[i].id === id) return some(items[i]);
    }
    return none();
}

function itemAt(items, index) {
    return index >= 0 && index < items.length ? some(items[index]) : none();
}

// What a popup shows for an id whose item has just gone: a blank card for
// the moment before the popup list catches up.
function placeholderItem(id) {
    return normaliseItem({id: id});
}

function hidePopup(state, id) {
    return {items: state.items, status: state.status, popups: state.popups.filter(function (p) { return p !== id; })};
}

// ---------------------------------------------------------------- client ops

function subscribeOp() { return JSON.stringify({op: "subscribe"}) + "\n"; }
function dismissOp(id) { return JSON.stringify({op: "dismiss", id: id}) + "\n"; }
function actionOp(id, key) { return JSON.stringify({op: "action", id: id, key: key}) + "\n"; }
function dismissAllOp() { return JSON.stringify({op: "dismiss_all"}) + "\n"; }

// Reconnect delay after the nth failed attempt: 1, 2, 4, 8, 16, then 30 s.
function backoffMs(attempt) {
    return Math.min(30000, 1000 * Math.pow(2, Math.max(0, attempt)));
}

// ---------------------------------------------------------------- connection
//
// The socket's state is one tagged value:
//   connecting         {attempt}           a socket is opening
//   awaiting_snapshot  {attempt}           open, subscribed, no snapshot yet
//   connected          {}                  a snapshot came in; items are live
//   offline            {attempt, retryAt}  down; the next try is at retryAt
// attempt counts the failures since the last snapshot and sets the backoff.
// Each input below is a pure transition; an input that does not apply to the
// current state returns that state unchanged.

var CONNECTION_KINDS = ["connecting", "awaiting_snapshot", "connected", "offline"];
var SNAPSHOT_WAIT_MS = 5000;

function connectionStart() {
    return {kind: "connecting", attempt: 0};
}

function socketOpened(c) {
    return c.kind === "connecting" ? {kind: "awaiting_snapshot", attempt: c.attempt} : c;
}

function snapshotReceived(c) {
    return c.kind === "awaiting_snapshot" || c.kind === "connected" ? {kind: "connected"} : c;
}

function socketLost(c, now) {
    if (c.kind === "offline") return c;
    const attempt = c.kind === "connected" ? 0 : c.attempt;
    return {kind: "offline", attempt: attempt + 1, retryAt: now + backoffMs(attempt)};
}

// A daemon that takes the connection but never sends its snapshot is as good
// as down.
function snapshotTimedOut(c, now) {
    return c.kind === "awaiting_snapshot" ? socketLost(c, now) : c;
}

function retryDue(c) {
    return c.kind === "offline" ? {kind: "connecting", attempt: c.attempt} : c;
}

// The reader asked to try again: skip the wait and start the backoff over.
function retryNow(c) {
    return c.kind === "offline" || c.kind === "awaiting_snapshot" ? {kind: "connecting", attempt: 0} : c;
}

// What the view shows for a connection and its items:
//   offline {retryInSeconds}, connecting, empty, ready
var VIEW_KINDS = ["offline", "connecting", "empty", "ready"];

function viewState(c, items, now) {
    if (c.kind === "offline") {
        return {kind: "offline", retryInSeconds: Math.max(0, Math.ceil((c.retryAt - now) / 1000))};
    }
    if (c.kind !== "connected") return {kind: "connecting"};
    return items.length > 0 ? {kind: "ready"} : {kind: "empty"};
}

// ---------------------------------------------------------------- readouts

// How long a popup stays: {kind: "after", ms} or {kind: "never"} for an
// urgent item. The daemon does not pass the app's expire_timeout, so urgency
// decides.
function popupTimeout(item) {
    if (item.urgency === URGENCY_CRITICAL) return {kind: "never"};
    return {kind: "after", ms: item.urgency === URGENCY_LOW ? 4000 : 7000};
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// The reader's calendar day for an epoch, as "Oct 18". tzOffsetMinutes is
// the local offset east of UTC (+840 in Kiritimati, -720 at UTC-12). The
// epoch is shifted by it and then read only with UTC accessors, so the result
// depends on the arguments and never on the machine's time zone.
function calendarDay(epochMs, tzOffsetMinutes) {
    const local = new Date(epochMs + tzOffsetMinutes * 60000);
    return MONTHS[local.getUTCMonth()] + " " + local.getUTCDate();
}

// The local offset east of UTC at one moment, for calendarDay. Only the QML
// caller reads the machine's zone, and only through this.
function localOffsetMinutes(epochMs) {
    return -new Date(epochMs).getTimezoneOffset();
}

// "now", "4 min", "3 h", "Oct 18". A missing time, or one more than two
// minutes in the future (clock skew between hosts), shows nothing.
function relativeTime(ms, now, tzOffsetMinutes) {
    if (!ms) return "";
    const delta = now - ms;
    if (delta < -120000) return "";
    if (delta < 60000) return "now";
    if (delta < 3600000) return Math.floor(delta / 60000) + " min";
    if (delta < 86400000) return Math.floor(delta / 3600000) + " h";
    return calendarDay(ms, tzOffsetMinutes);
}

// The app's display name. Empty names fall back to the host, then a word.
function appLabel(item) {
    if (item.app_name !== "") return item.app_name;
    if (item.origin === "remote" && item.host !== "") return item.host;
    return "Notification";
}

// Where the item came from, or "" for an ordinary local item.
function originLabel(item) {
    if (item.origin === "remote") return item.host !== "" ? "from " + item.host : "from another device";
    return "";
}

// A local_only item never leaves this machine.
function localOnlyLabel(item) {
    if (!item.local_only) return "";
    return item.host !== "" ? "Only on " + item.host : "Only on this device";
}

// The text the card leads with. A notification can arrive with no summary.
function headline(item) {
    if (item.summary !== "") return item.summary;
    if (item.body !== "") return "";
    return appLabel(item);
}

// Buttons in the order the app sent them. "default" is what a click on the
// notification does, so it is labelled for that.
function buttonLabel(action) {
    if (action.key === "default" && (action.label === "" || action.label.toLowerCase() === "default")) return "Open";
    return action.label !== "" ? action.label : action.key;
}

// The app's "default" action, as {kind: "some", value: {action, index}}.
function defaultAction(item) {
    for (let i = 0; i < item.actions.length; i++) {
        if (item.actions[i].key === "default") return some({action: item.actions[i], index: i});
    }
    return none();
}

// What Enter runs on a selected item: the default action, else the first.
function enterAction(item) {
    const fallback = defaultAction(item);
    if (fallback.kind === "some") return fallback;
    return item.actions.length > 0 ? some({action: item.actions[0], index: 0}) : none();
}

// A file URL for a path or file URL, as some(url); none for anything else.
function fileUrl(value) {
    if (typeof value !== "string" || value === "") return none();
    if (value.indexOf("file://") === 0) return some(value);
    if (value.charAt(0) === "/") return some("file://" + value);
    return none();
}

// The icon a card shows: {kind: "image", url} or {kind: "letter", letter}.
// app_icon carries a path or an icon name. themeIcon(name) and
// entryIcon(appName) are the caller's lookups, each returning some(url) or
// none(), so the order lives here and the platform lookups stay in QML.
function iconChoice(item, themeIcon, entryIcon) {
    const path = fileUrl(item.app_icon);
    if (path.kind === "some") return {kind: "image", url: path.value};
    if (item.app_icon !== "") {
        const named = themeIcon(item.app_icon);
        if (named.kind === "some") return {kind: "image", url: named.value};
    }
    if (item.app_name !== "") {
        const fromEntry = entryIcon(item.app_name);
        if (fromEntry.kind === "some") return {kind: "image", url: fromEntry.value};
    }
    return {kind: "letter", letter: letter(item)};
}

function letter(item) {
    const text = appLabel(item);
    return text.length > 0 ? text.charAt(0).toUpperCase() : "?";
}

// The bar's words. The view state wins over the count, because a count from
// a dead socket would be a lie.
function barText(view, status, count, wide) {
    if (view.kind === "offline") return wide ? "Notifications offline" : "NTF !";
    if (view.kind === "connecting") return wide ? "Notifications" : "NTF";
    if (wide) {
        let text = count > 0 ? "Notifications " + count : "Notifications";
        if (status.server === "unreachable") text += ", local only";
        return text;
    }
    return count > 0 ? "NTF " + count : "NTF";
}

// The bar control's colour, as a tone the caller maps to a Theme colour.
// Red: an urgent item is open. Amber: notifyd or the sync server is out of
// reach.
function barTone(view, status, items) {
    if (view.kind === "offline") return "warning";
    if (view.kind === "connecting") return "muted";
    if (items.some(function (i) { return i.urgency === URGENCY_CRITICAL; })) return "danger";
    if (status.server === "unreachable") return "warning";
    return items.length > 0 ? "primary" : "muted";
}

// The centre's status badge: {kind: "local_only", text} while the sync
// server is out of reach, {kind: "connecting", text} while notifyd is still
// reaching it, else {kind: "none"}.
function statusBadge(view, status) {
    if (view.kind !== "ready" && view.kind !== "empty") return none();
    if (status.server === "unreachable") {
        return {kind: "local_only", text: status.outbox > 0 ? "Local only, " + status.outbox + " queued" : "Local only"};
    }
    if (status.server === "connecting") return {kind: "connecting", text: "Connecting to sync server"};
    return none();
}

// ---------------------------------------------------------------- layout

// Every threshold below is a guess until measured on myoko; each one is named
// so notification-model.test.js can test one unit either side of it.
const EDGE = 6;            // gap from a screen edge
const BAR_CLEAR = 32;      // the top bar plus a gap, as the other panels use
const POPUP_MAX_W = 380;
const CENTRE_MAX_W = 440;
const CARD_MIN_POPUP_H = 96;
const MORE_CHIP_H = 30;
const POPUP_GAP = 6;
const POPUP_MAX_COUNT = 4;

// The popup stack, from the screen it is drawn on.
function popupPlan(width, height) {
    const cardWidth = Math.max(0, Math.min(POPUP_MAX_W, width - 2 * EDGE));
    const room = Math.max(0, height - BAR_CLEAR - EDGE);
    return {
        cardWidth: cardWidth,
        maxHeight: room,
        gap: POPUP_GAP,
        chipHeight: MORE_CHIP_H,
        maxCount: POPUP_MAX_COUNT,
        // Body lines are the first thing a short screen gives up, before the
        // number of cards.
        bodyLines: room >= 4 * (CARD_MIN_POPUP_H + POPUP_GAP) ? 3 : 2
    };
}

// How many popups, newest first, fit in room. heights are the cards' own
// heights. When some are left over, the chip that opens the centre needs room
// too. The newest popup always shows, so a fresh notification is never lost.
function fitPopups(heights, room, gap, chipHeight, maxCount) {
    const total = heights.length;
    const limit = Math.min(total, maxCount);
    let used = 0;
    let visible = 0;
    for (let i = 0; i < limit; i++) {
        const next = used + (i > 0 ? gap : 0) + heights[i];
        const rest = total - (i + 1);
        const reserve = rest > 0 ? gap + chipHeight : 0;
        if (i > 0 && next + reserve > room) break;
        used = next;
        visible = i + 1;
    }
    // The chip must fit after the last visible card; drop cards until it does.
    while (visible > 1 && visible < total && used + gap + chipHeight > room) {
        used -= heights[visible - 1] + gap;
        visible -= 1;
    }
    return {visible: visible, hidden: total - visible};
}

// The centre card, from the screen it is drawn on. Height decides structure,
// width decides content.
function centrePlan(width, height) {
    const cardWidth = Math.max(0, Math.min(CENTRE_MAX_W, width - 2 * EDGE));
    const maxHeight = Math.max(0, height - BAR_CLEAR - EDGE);
    const padding = maxHeight < 360 || cardWidth < 300 ? 8 : 12;
    return {
        cardWidth: cardWidth,
        maxHeight: maxHeight,
        padding: padding,
        // The status badge is a readout; it moves under the title before the
        // title row gives up a control.
        badgeOwnRow: cardWidth < 360,
        // "Dismiss all" keeps its words while it fits, then becomes "All".
        dismissAllLabel: cardWidth >= 300 ? "Dismiss all" : "All",
        showHint: maxHeight >= 400 && cardWidth >= 300,
        bodyLines: maxHeight >= 600 ? 6 : 3
    };
}

// One notification card, from the width it is given. Used by the popups and
// the centre alike.
function cardPlan(width, hasImage) {
    const inner = Math.max(0, width - 2 * (width < 260 ? 8 : 10));
    // Host and time are readouts. Below this width they leave the title row
    // for a line of their own, so the dismiss control keeps its place.
    const metaInline = width >= 300;
    const imageSide = hasImage && width >= 300;
    const imageSize = Math.round(Math.max(40, Math.min(64, width * 0.16)));
    return {
        padding: width < 260 ? 8 : 10,
        inner: inner,
        metaInline: metaInline,
        imageSide: imageSide,
        imageBelow: hasImage && !imageSide,
        imageSize: imageSide ? imageSize : 0,
        imageBelowHeight: Math.round(Math.min(120, inner * 0.5)),
        buttonMaxWidth: Math.max(0, inner)
    };
}
