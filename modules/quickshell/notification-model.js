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

// One socket line to one event, or null. Unknown types are ignored, so a
// newer daemon can add events without breaking an older view.
function parseLine(line) {
    let value;
    try {
        value = JSON.parse(line);
    } catch (e) {
        return null;
    }
    if (!value || typeof value !== "object") return null;
    if (value.type === "snapshot") {
        const items = Array.isArray(value.items) ? value.items.map(normaliseItem).filter(Boolean) : [];
        return {type: "snapshot", items: items, status: normaliseStatus(value.status)};
    }
    if (value.type === "upsert") {
        const item = normaliseItem(value.item);
        return item ? {type: "upsert", item: item, fresh: value.fresh === true} : null;
    }
    if (value.type === "remove") {
        return typeof value.id === "number" ? {type: "remove", id: value.id, reason: num(value.reason, 0)} : null;
    }
    if (value.type === "status") {
        return {type: "status", status: normaliseStatus(value.status)};
    }
    return null;
}

// Fold one event into {items, status, popups}. popups lists the ids that show
// a popup, newest first. The result is a new object; the input is not changed.
function applyEvent(state, event) {
    if (!event) return state;
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

// ---------------------------------------------------------------- readouts

// How long a popup stays before it hides. 0 means it stays until dismissed.
// The daemon does not pass the app's expire_timeout, so urgency decides.
function popupTimeoutMs(item) {
    if (!item) return 0;
    if (item.urgency === URGENCY_CRITICAL) return 0;
    return item.urgency === URGENCY_LOW ? 4000 : 7000;
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// "now", "4 min", "3 h", "Oct 18". A missing or future time reads "now"
// within two minutes and is left blank beyond that.
function relativeTime(ms, now) {
    if (!ms) return "";
    const delta = now - ms;
    if (delta < -120000) return "";
    if (delta < 60000) return "now";
    if (delta < 3600000) return Math.floor(delta / 60000) + " min";
    if (delta < 86400000) return Math.floor(delta / 3600000) + " h";
    const d = new Date(ms);
    return MONTHS[d.getMonth()] + " " + d.getDate();
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

function defaultAction(item) {
    for (let i = 0; i < item.actions.length; i++) {
        if (item.actions[i].key === "default") return item.actions[i];
    }
    return null;
}

// "file:///…" for a path, "" for anything that is not a path. Icon names go
// through Quickshell.iconPath in QML.
function fileUrl(value) {
    if (!value) return "";
    if (value.indexOf("file://") === 0) return value;
    if (value.charAt(0) === "/") return "file://" + value;
    return "";
}

function letter(item) {
    const text = appLabel(item);
    return text.length > 0 ? text.charAt(0).toUpperCase() : "?";
}

// The bar's words. Connection state wins over the count, because a count from
// a dead socket would be a lie.
function barText(online, connecting, status, count, wide) {
    if (!online) {
        if (connecting) return wide ? "Notifications" : "NTF";
        return wide ? "Notifications offline" : "NTF !";
    }
    if (wide) {
        let text = count > 0 ? "Notifications " + count : "Notifications";
        if (status.server === "unreachable") text += ", local only";
        return text;
    }
    return count > 0 ? "NTF " + count : "NTF";
}

// "Local only" plus what waits to sync. Empty while the server answers.
function serverBadge(status) {
    if (status.server !== "unreachable") return "";
    return status.outbox > 0 ? "Local only, " + status.outbox + " queued" : "Local only";
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
