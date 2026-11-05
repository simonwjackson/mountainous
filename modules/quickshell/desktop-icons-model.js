.pragma library
// The desktop icon layer's policy: the session with Hensou Files' desktop
// provider, the icons it supplies, selection, keyboard navigation, drag and
// drop, the context menus and the confirmations of each theme. Pure, so
// desktop-icons-model.test.js runs it under node; DesktopIcons.qml and
// DesktopIconSession.qml do the drawing and the socket.
//
// The protocol is Hensou's crates/desktop-protocol (ADR 0006): JSON lines
// on $XDG_RUNTIME_DIR/hensou/desktop.sock. The shell says Hello, then
// Subscribe with its theme and the primary screen's layout, draws the
// Snapshot and applies Changed deltas. The provider owns positions, Snap
// to Grid and arrangement; the shell sends intents only.
//
// Theme ids are the persisted ones: "platinum" and "win98" (Memphis).

var MAJOR = 1;
var MINOR = 0;
// Quiet retries while the provider is down: never an alert, never stale
// icons shown as live.
var RETRY_MS = [500, 1000, 2000, 4000, 8000];
// A refused Hello (another major version) waits longer between tries.
var REFUSED_RETRY_MS = 30000;
// Pixels the pointer moves before a press becomes a drag.
var DRAG_THRESHOLD = 4;
// The provider's grid when it has not sent one.
var DEFAULT_GRID = { cell_width: 80, cell_height: 72 };

function themeOf(theme) { return theme === "win98" ? "win98" : "platinum"; }

// ------------------------------------------------------------- the screen

// The bars each theme reserves, in logical px (Platinum: the menu bar on
// top, the Control Strip's band below; Memphis: the 28 u taskbar, whose
// zone rounds up; 1 u = 2 device px).
function reserved(theme, dpr) {
    var ratio = dpr > 0 ? dpr : 1;
    if (themeOf(theme) === "win98")
        return { top: 0, bottom: Math.ceil(28 * 2 / ratio - 1e-6), left: 0, right: 0 };
    return { top: 28, bottom: 42, left: 0, right: 0 };
}

// The protocol's ScreenLayout for the primary screen: output name, size
// and scale, and the area icons may use (without the bar or taskbar).
// screen: { name, width, height, scale }.
function screenLayout(theme, screen) {
    var s = screen || {};
    var w = Math.max(0, Math.round(s.width || 0)), h = Math.max(0, Math.round(s.height || 0));
    var scale = s.scale > 0 ? s.scale : 1;
    var r = reserved(theme, scale);
    return {
        output: String(s.name || ""),
        width: w,
        height: h,
        scale: scale,
        usable: { x: r.left, y: r.top, width: Math.max(0, w - r.left - r.right), height: Math.max(0, h - r.top - r.bottom) }
    };
}

// Two subscriptions are the same when the theme and the layout are.
function layoutKey(theme, layout) {
    var l = layout || {};
    var u = l.usable || {};
    return [themeOf(theme), l.output, l.width, l.height, l.scale, u.x, u.y, u.width, u.height].join("|");
}

// ------------------------------------------------------------ the session

// kind: "down" (no socket), "connecting", "hello" (Hello sent),
// "waiting-layout" (Hello answered, no screen yet), "subscribing"
// (Subscribe sent, no Snapshot yet), "live", "refused" (another major).
function initial() {
    return { kind: "down", attempts: 0, icons: [], snap: false, grid: DEFAULT_GRID, theme: "", layout: null, key: "", retryMs: 0 };
}

function copy(state, changes) {
    var out = {};
    var k;
    for (k in state) out[k] = state[k];
    for (k in changes) out[k] = changes[k];
    return out;
}

// One line on the wire.
function encode(message) { return JSON.stringify(message) + "\n"; }

function helloMessage() { return { type: "hello", major: MAJOR, minor: MINOR }; }
function subscribeMessage(theme, layout) { return { type: "subscribe", theme: themeOf(theme), screen: layout }; }

// The icons are drawn only while the session is live. A session that is
// resubscribing keeps drawing what the provider last said: it is still the
// provider's live state.
function shown(state) {
    return state.kind === "live" || (state.kind === "subscribing" && state.icons.length > 0);
}

// Events: { type: "connect" } (start a socket), { type: "opened" },
// { type: "lost" }, { type: "line", data }, { type: "layout", theme, layout },
// { type: "retry" }. Returns { state, send: [messages], effects: [...] }.
// Effects: { type: "open-socket" }, { type: "close-socket" },
// { type: "retry", ms }, { type: "confirm", request, ids, confirmation },
// { type: "error", code, message, ids }, { type: "changed", upsert, removed }.
function reduce(state, event) {
    var send = [], effects = [];
    var s = state;
    switch (event.type) {
    case "connect":
    case "retry":
        if (s.kind === "down" || s.kind === "refused") {
            s = copy(s, { kind: "connecting" });
            effects.push({ type: "open-socket" });
        }
        break;
    case "opened":
        if (s.kind === "connecting") {
            s = copy(s, { kind: "hello" });
            send.push(helloMessage());
        }
        break;
    case "lost":
        if (s.kind !== "down") {
            var wait = RETRY_MS[Math.min(s.attempts, RETRY_MS.length - 1)];
            if (s.kind === "refused") wait = REFUSED_RETRY_MS;
            // Stale icons are never shown as live: drop them now.
            s = copy(s, { kind: s.kind === "refused" ? "refused" : "down", icons: [], attempts: s.attempts + 1, retryMs: wait });
            effects.push({ type: "close-socket" });
            effects.push({ type: "retry", ms: wait });
        }
        break;
    case "layout":
        var key = layoutKey(event.theme, event.layout);
        s = copy(s, { theme: themeOf(event.theme), layout: event.layout });
        if (s.kind === "waiting-layout" || ((s.kind === "subscribing" || s.kind === "live") && key !== s.key)) {
            s = copy(s, { kind: "subscribing", key: key });
            send.push(subscribeMessage(s.theme, s.layout));
        }
        break;
    case "line":
        var m = parse(event.data);
        if (!m) break;
        return handle(s, m, send, effects);
    }
    return { state: s, send: send, effects: effects };
}

function parse(data) {
    var text = String(data || "").trim();
    if (text === "") return null;
    try {
        var m = JSON.parse(text);
        return m && typeof m === "object" && typeof m.type === "string" ? m : null;
    } catch (e) {
        return null;
    }
}

function subscribeIfReady(s, send) {
    if (!s.layout || s.theme === "") return s;
    send.push(subscribeMessage(s.theme, s.layout));
    return copy(s, { kind: "subscribing", key: layoutKey(s.theme, s.layout) });
}

function handle(s, m, send, effects) {
    switch (m.type) {
    case "hello":
        if (s.kind !== "hello") break;
        if (m.major !== MAJOR) {
            s = copy(s, { kind: "refused" });
            effects.push({ type: "close-socket" });
            effects.push({ type: "retry", ms: REFUSED_RETRY_MS });
            break;
        }
        // Without a layout yet, the next layout event subscribes.
        s = subscribeIfReady(copy(s, { kind: "waiting-layout", attempts: 0 }), send);
        break;
    case "snapshot":
        if (s.kind !== "subscribing" && s.kind !== "live") break;
        s = copy(s, {
            kind: "live",
            icons: Array.isArray(m.icons) ? m.icons.filter(validIcon) : [],
            snap: m.snap === true,
            grid: m.grid && m.grid.cell_width > 0 && m.grid.cell_height > 0 ? m.grid : DEFAULT_GRID
        });
        break;
    case "changed":
        if (s.kind !== "live") break;
        s = copy(s, { icons: applyChanged(s.icons, m.upsert, m.removed) });
        effects.push({ type: "changed", upsert: (m.upsert || []).map(function (i) { return i.id; }), removed: m.removed || [] });
        break;
    case "snap":
        s = copy(s, { snap: m.snap === true });
        break;
    case "confirm-needed":
        effects.push({ type: "confirm", request: m.request, ids: m.ids || [], confirmation: m.confirmation || {} });
        break;
    case "error":
        if (m.code === "version") {
            s = copy(s, { kind: "refused", icons: [] });
            effects.push({ type: "close-socket" });
            effects.push({ type: "retry", ms: REFUSED_RETRY_MS });
            break;
        }
        effects.push({ type: "error", code: String(m.code || "other"), message: String(m.message || ""), ids: m.ids || [] });
        break;
    }
    return { state: s, send: send, effects: effects };
}

function validIcon(i) {
    return !!i && typeof i.id === "string" && i.id !== "" && !!i.position;
}

// The icons keep the provider's order (the snapshot's, new ones from
// Changed at the end): Tab walks it and the drawing stacks in it. When the
// desktop has more icons than grid cells the provider cascades the extra
// ones 12 px apart, so icons can overlap; this order still reaches each.
// Reading order (top to bottom, then left to right), for the Shift run.
function sortIcons(icons) {
    return icons.slice().sort(function (a, b) {
        return a.position.y - b.position.y || a.position.x - b.position.x || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
    });
}

// Upserts by id in place, new icons at the end, then removals (the
// protocol's order).
function applyChanged(icons, upsert, removed) {
    var byId = {};
    var order = [];
    var i;
    for (i = 0; i < icons.length; i++) { byId[icons[i].id] = icons[i]; order.push(icons[i].id); }
    var up = (upsert || []).filter(validIcon);
    for (i = 0; i < up.length; i++) {
        if (!(up[i].id in byId)) order.push(up[i].id);
        byId[up[i].id] = up[i];
    }
    var gone = {};
    for (i = 0; i < (removed || []).length; i++) gone[removed[i]] = true;
    return order.filter(function (id) { return !gone[id]; }).map(function (id) { return byId[id]; });
}

function find(icons, id) {
    for (var i = 0; i < icons.length; i++) if (icons[i].id === id) return icons[i];
    return null;
}

// -------------------------------------------------------------- selection

// A click on an icon. mods: { shift, ctrl }. Platinum's Shift and
// Memphis's Ctrl add or remove one icon; Memphis's Shift selects the run
// from the anchor in reading order. A plain click on a selected icon keeps
// the selection (a drag may follow); release() narrows it.
// Returns { selection, anchor }.
function click(theme, icons, sel, anchor, id, mods) {
    var m = mods || {};
    var has = sel.indexOf(id) >= 0;
    if (themeOf(theme) === "win98" && m.shift && anchor) {
        var ids = sortIcons(icons).map(function (i) { return i.id; });
        var a = ids.indexOf(anchor), b = ids.indexOf(id);
        if (a >= 0 && b >= 0) {
            var lo = Math.min(a, b), hi = Math.max(a, b);
            var run = ids.slice(lo, hi + 1);
            if (m.ctrl) run = sel.concat(run.filter(function (x) { return sel.indexOf(x) < 0; }));
            return { selection: run, anchor: anchor };
        }
    }
    var toggles = themeOf(theme) === "win98" ? m.ctrl : (m.shift || m.ctrl);
    if (toggles) {
        return { selection: has ? sel.filter(function (x) { return x !== id; }) : sel.concat([id]), anchor: id };
    }
    if (has) return { selection: sel, anchor: id };
    return { selection: [id], anchor: id };
}

// A plain click released without a drag on an icon of a larger selection
// selects that icon alone.
function release(sel, id, mods, dragged) {
    var m = mods || {};
    if (dragged || m.shift || m.ctrl || sel.indexOf(id) < 0) return sel;
    return [id];
}

function intersects(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

// A rectangle from two corners, any direction.
function band(x0, y0, x1, y1) {
    return { x: Math.min(x0, x1), y: Math.min(y0, y1), w: Math.abs(x1 - x0), h: Math.abs(y1 - y0) };
}

// The icons a rubber band touches. boxes: [{ id, rects: [{x, y, w, h}] }]
// (the image and the label of each icon). additive keeps base (Shift or
// Ctrl held when the band started); toggling as both OSes did is kept
// simple: the band adds.
function bandSelection(boxes, rect, base, additive) {
    var hit = [];
    for (var i = 0; i < boxes.length; i++) {
        var rects = boxes[i].rects || [];
        for (var k = 0; k < rects.length; k++) if (intersects(rects[k], rect)) { hit.push(boxes[i].id); break; }
    }
    if (!additive) return hit;
    return base.concat(hit.filter(function (id) { return base.indexOf(id) < 0; }));
}

// ------------------------------------------------------ keyboard movement

function centre(box) {
    var r = box.rects && box.rects.length ? box.rects[0] : box;
    return { x: r.x + r.w / 2, y: r.y + r.h / 2 };
}

// The icon an arrow key moves to from `from` ("left", "right", "up",
// "down"), by the icons' image centres: the nearest one on that side,
// favouring the same row or column. With nothing selected, the first icon
// in reading order. Returns an id, or `from` when nothing is that way.
function neighbour(boxes, from, dir) {
    if (boxes.length === 0) return "";
    var start = null;
    for (var i = 0; i < boxes.length; i++) if (boxes[i].id === from) start = boxes[i];
    if (!start) return readingOrder(boxes)[0].id;
    var c0 = centre(start);
    var best = null, bestScore = Infinity;
    for (i = 0; i < boxes.length; i++) {
        if (boxes[i] === start) continue;
        var c = centre(boxes[i]);
        var dx = c.x - c0.x, dy = c.y - c0.y;
        if (Math.abs(dx) < 0.5 && Math.abs(dy) < 0.5) {
            // Stacked exactly on the start: Right and Down go to the next
            // in the provider's order, Left and Up to the previous one.
            var later = boxes.indexOf(boxes[i]) > boxes.indexOf(start);
            var forward = dir === "right" || dir === "down";
            if (later === forward) {
                var tie = forward ? 0.25 + i * 1e-6 : 0.25 + (boxes.length - i) * 1e-6;
                if (tie < bestScore) { bestScore = tie; best = boxes[i]; }
            }
            continue;
        }
        var along, across;
        if (dir === "right") { along = dx; across = Math.abs(dy); }
        else if (dir === "left") { along = -dx; across = Math.abs(dy); }
        else if (dir === "down") { along = dy; across = Math.abs(dx); }
        else { along = -dy; across = Math.abs(dx); }
        // Ahead, inside the 45-degree cone on that side.
        if (along <= 0.5) continue;
        if (across > along + 8) continue;
        var score = along + across * 2;
        if (score < bestScore) { bestScore = score; best = boxes[i]; }
    }
    return best ? best.id : from;
}

function readingOrder(boxes) {
    return boxes.slice().sort(function (a, b) {
        var ca = centre(a), cb = centre(b);
        return ca.y - cb.y || ca.x - cb.x;
    });
}

// Tab and Shift+Tab: the next or previous icon in the provider's order,
// cycling, so every icon is reachable even when others cover it. icons:
// the session's list; from: the focused id ("" starts at either end).
function tabNext(icons, from, back) {
    if (icons.length === 0) return "";
    var at = -1;
    for (var i = 0; i < icons.length; i++) if (icons[i].id === from) at = i;
    if (at < 0) return icons[back ? icons.length - 1 : 0].id;
    return icons[(at + (back ? icons.length - 1 : 1)) % icons.length].id;
}

// The stacking of an icon: the provider's order, with the selected icons
// above every unselected one and the focused icon above them all, so the
// icon the keyboard is on shows even inside a cascade.
function zFor(icons, id, selection, focused) {
    var n = icons.length;
    var at = 0;
    for (var i = 0; i < n; i++) if (icons[i].id === id) at = i;
    if (id !== "" && id === focused) return 2 * n + 1;
    if (selection.indexOf(id) >= 0) return n + at;
    return at;
}

// Home and End: the first and last icon in reading order.
function edge(boxes, last) {
    if (boxes.length === 0) return "";
    var o = readingOrder(boxes);
    return o[last ? o.length - 1 : 0].id;
}

// Typing a letter selects the next icon whose label starts with it, after
// the current one in alphabetical order, cycling (both Finder and Explorer).
function byLetter(icons, from, letter) {
    var l = String(letter || "").toLowerCase();
    if (l === "") return from;
    var sorted = icons.slice().sort(function (a, b) { return String(a.label).localeCompare(String(b.label)); });
    var hits = sorted.filter(function (i) { return String(i.label).toLowerCase().indexOf(l) === 0; });
    if (hits.length === 0) return from;
    var at = -1;
    for (var i = 0; i < hits.length; i++) if (hits[i].id === from) at = i;
    return hits[(at + 1) % hits.length].id;
}

// ------------------------------------------------------------ drag and drop

// The kinds an icon can be dropped on.
var DROP_KINDS = ["trash", "folder", "volume"];

function canAccept(icon) {
    return !!icon && DROP_KINDS.indexOf(icon.kind) >= 0 && icon.available !== false;
}

// The icon under the pointer that takes a drop, or "" (dragged icons and
// icons that take nothing never do).
function dropTarget(icons, boxes, x, y, dragging) {
    for (var i = boxes.length - 1; i >= 0; i--) {
        var b = boxes[i];
        if (dragging.indexOf(b.id) >= 0) continue;
        var rects = b.rects || [];
        for (var k = 0; k < rects.length; k++) {
            var r = rects[k];
            if (x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h)
                return canAccept(find(icons, b.id)) ? b.id : "";
        }
    }
    return "";
}

// The Move message for icons dragged by (dx, dy): each new top-left,
// inside the usable area (positions are relative to it). The provider
// snaps and resolves overlaps.
function moves(icons, ids, dx, dy, usable, grid) {
    var g = grid || DEFAULT_GRID;
    var u = usable || { width: 1e9, height: 1e9 };
    var out = [];
    for (var i = 0; i < ids.length; i++) {
        var icon = find(icons, ids[i]);
        if (!icon) continue;
        var x = Math.round(icon.position.x + dx), y = Math.round(icon.position.y + dy);
        x = Math.max(0, Math.min(x, Math.max(0, u.width - g.cell_width)));
        y = Math.max(0, Math.min(y, Math.max(0, u.height - g.cell_height)));
        out.push([icon.id, { x: x, y: y }]);
    }
    return out;
}

// What ending a drag sends: Drop on a target, else Move, else nothing.
function endDrag(icons, ids, target, dx, dy, usable, grid) {
    if (ids.length === 0) return null;
    if (target) return { type: "drop", ids: ids.slice(), target: target };
    if (Math.abs(dx) < 1 && Math.abs(dy) < 1) return null;
    return { type: "move", moves: moves(icons, ids, dx, dy, usable, grid) };
}

// ---------------------------------------------------------------- actions

function canRename(icon) {
    return !!icon && icon.available !== false && ["file", "folder", "alias", "launcher"].indexOf(icon.kind) >= 0;
}
function canTrash(icon) {
    return !!icon && ["file", "folder", "alias", "launcher"].indexOf(icon.kind) >= 0;
}
function canEject(icon) {
    return !!icon && icon.kind === "volume" && icon.ejectable !== false;
}

// A rename the provider should hear about: a changed, non-empty name with
// no path separator. Returns the trimmed name or "".
function renameTo(icon, text) {
    var name = String(text || "").trim();
    if (!icon || name === "" || name === icon.label || name.indexOf("/") >= 0 || name === "." || name === "..") return "";
    return name;
}

// --------------------------------------------------------------- the menus

// A row: { id, label, action, separator, checked, disabled, submenu, bold }.
// Labels are each OS's own: Platinum's "Move to Trash", Memphis's "Delete".
function sep() { return { separator: true }; }

// The menu for the icons `ids` (the one right-clicked is `id`).
function iconMenu(theme, icons, ids, id) {
    var t = themeOf(theme);
    var icon = find(icons, id);
    if (!icon) return [];
    var many = ids.length > 1;
    var targets = ids.map(function (x) { return find(icons, x); }).filter(Boolean);
    var allTrash = targets.length > 0 && targets.every(canTrash);
    var rows = [];
    if (t === "win98") {
        rows.push({ id: "open", label: "&Open", action: "open", bold: true, disabled: icon.available === false });
        if (icon.kind === "trash") {
            rows.push(sep());
            rows.push({ id: "empty-trash", label: "Empty Recycle &Bin", action: "empty-trash", disabled: icon.full === false });
        }
        if (icon.kind === "volume") {
            rows.push(sep());
            rows.push({ id: "eject", label: "&Eject", action: "eject", disabled: !canEject(icon) });
        }
        if (allTrash || canRename(icon)) {
            rows.push(sep());
            if (allTrash) rows.push({ id: "trash", label: "&Delete", action: "trash" });
            if (canRename(icon)) rows.push({ id: "rename", label: "Rena&me", action: "rename", disabled: many });
        }
        return rows;
    }
    rows.push({ id: "open", label: "Open", action: "open", disabled: icon.available === false });
    if (allTrash) rows.push({ id: "trash", label: "Move to Trash", action: "trash" });
    if (icon.kind === "trash") rows.push({ id: "empty-trash", label: "Empty Trash…", action: "empty-trash", disabled: icon.full === false });
    if (icon.kind === "volume") rows.push({ id: "eject", label: "Eject", action: "eject", disabled: !canEject(icon) });
    if (canRename(icon)) {
        rows.push(sep());
        rows.push({ id: "rename", label: "Rename", action: "rename", disabled: many });
    }
    return rows;
}

// The menu for the desktop itself. Snap to Grid is one shared setting.
function desktopMenu(theme, snap) {
    if (themeOf(theme) === "win98") {
        return [
            { id: "arrange", label: "Arrange &Icons", submenu: [
                { id: "by-name", label: "by &Name", action: "arrange", by: "name" },
                { id: "by-type", label: "by &Type", action: "arrange", by: "kind" },
                { id: "by-size", label: "by Si&ze", action: "arrange", by: "size" },
                { id: "by-date", label: "by &Date", action: "arrange", by: "date" },
                sep(),
                { id: "snap", label: "&Align to Grid", action: "snap", checked: snap === true }
            ] }
        ];
    }
    return [
        { id: "clean-up", label: "Clean Up", action: "arrange", by: "clean-up" },
        sep(),
        { id: "snap", label: "Always snap to grid", action: "snap", checked: snap === true }
    ];
}

// The message a chosen row sends, or a local step ("rename"). request:
// the next CheckTrash / CheckEmptyTrash request number.
function menuAction(row, ids, id, snap, request) {
    if (!row || row.disabled) return null;
    switch (row.action) {
    case "open": return { send: { type: "open", ids: ids.slice() } };
    case "trash": return { send: { type: "check-trash", request: request, ids: ids.slice() } };
    case "empty-trash": return { send: { type: "check-empty-trash", request: request } };
    case "eject": return { send: { type: "eject", id: id } };
    case "arrange": return { send: { type: "arrange", by: row.by } };
    case "snap": return { send: { type: "set-snap", snap: !snap } };
    case "rename": return { local: "rename", id: id };
    }
    return null;
}

// Win98Menu's items from rows ("&" marks the access key).
function win98Items(rows) {
    return rows.map(function (r) {
        if (r.separator) return { separator: true };
        var out = { text: r.label, enabled: !r.disabled, row: r };
        if (r.checked !== undefined) out.checked = r.checked;
        if (r.bold) out.bold = true;
        if (r.submenu) out.submenu = win98Items(r.submenu);
        return out;
    });
}

// PlatinumCascadeMenu's rows (themes/platinum/menu-models.js shape).
function platinumRows(rows) {
    return rows.map(function (r) {
        if (r.separator) return { kind: "separator" };
        var out = { kind: "item", id: r.id, label: r.label, disabled: !!r.disabled, spacer: true, action: { kind: "desktop", row: r } };
        if (r.checked !== undefined) out.check = r.checked;
        if (r.submenu) out.submenu = platinumRows(r.submenu);
        return out;
    });
}

// ---------------------------------------------------------- confirmations

function quoted(theme, name) {
    return themeOf(theme) === "win98" ? "'" + name + "'" : "“" + name + "”";
}

function plural(n, one, many) { return n === 1 ? one : many; }

// How a theme answers a ConfirmNeeded. Returns null when the theme acts at
// once (Platinum's Move to Trash), else an alert: { title, text, accept,
// cancel, defaultButton ("accept" | "cancel"), icon ("caution" | "question"
// | "warning"), send }. send is the message for the accepting button.
// names: the labels of the ids, for the text.
function confirmPlan(theme, confirmation, ids, names) {
    var t = themeOf(theme);
    var c = confirmation || {};
    var n = typeof c.count === "number" ? c.count : ids.length;
    var one = n === 1 && names && names.length === 1 ? names[0] : "";
    switch (c.type) {
    case "move-to-trash":
        if (t === "platinum") return null;
        return {
            title: n === 1 ? "Confirm File Delete" : "Confirm Multiple File Delete",
            text: one !== "" ? "Are you sure you want to send " + quoted(t, one) + " to the Recycle Bin?"
                : "Are you sure you want to send these " + n + " items to the Recycle Bin?",
            accept: "&Yes", cancel: "&No", defaultButton: "accept", icon: "recycle",
            send: { type: "trash", ids: ids.slice() }
        };
    case "permanent":
        var reason = String(c.reason || "");
        if (t === "win98") {
            return {
                title: n === 1 ? "Confirm File Delete" : "Confirm Multiple File Delete",
                text: (one !== "" ? "Are you sure you want to delete " + quoted(t, one) + "?"
                    : "Are you sure you want to delete these " + n + " items?")
                    + (reason !== "" ? "\n\n" + reason : "") + "\n\nYou cannot undo this action.",
                accept: "&Yes", cancel: "&No", defaultButton: "cancel", icon: "warning",
                send: { type: "delete-permanently", ids: ids.slice() }
            };
        }
        return {
            title: one !== "" ? "The item " + quoted(t, one) + " will be deleted immediately."
                : "These " + n + " items will be deleted immediately.",
            text: (reason !== "" ? reason + " " : "") + "You can’t undo this action.",
            accept: "Delete", cancel: "Cancel", defaultButton: "cancel", icon: "caution",
            send: { type: "delete-permanently", ids: ids.slice() }
        };
    case "empty-trash":
        if (t === "win98") {
            return {
                title: n === 1 ? "Confirm File Delete" : "Confirm Multiple File Delete",
                text: n === 1 ? "Are you sure you want to delete this item from the Recycle Bin?"
                    : "Are you sure you want to delete these " + n + " items?",
                accept: "&Yes", cancel: "&No", defaultButton: "cancel", icon: "warning",
                send: { type: "empty-trash" }
            };
        }
        return {
            title: "The Trash contains " + n + " " + plural(n, "item", "items") + ".",
            text: "Are you sure you want to permanently remove " + plural(n, "this item", "these items") + "?",
            accept: "OK", cancel: "Cancel", defaultButton: "cancel", icon: "caution",
            send: { type: "empty-trash" }
        };
    }
    return null;
}

// A provider Error as a themed alert: { title, text, accept: "OK", icon }.
function errorPlan(theme, error, names) {
    var t = themeOf(theme);
    var e = error || {};
    var name = names && names.length === 1 ? names[0] : "";
    var text = String(e.message || "");
    var title;
    if (e.code === "busy") {
        title = t === "win98"
            ? (name !== "" ? "Windows cannot eject " + quoted(t, name) + " right now." : "The device cannot be stopped right now.")
            : (name !== "" ? "The disk " + quoted(t, name) + " could not be put away, because it is in use." : "The disk could not be put away, because it is in use.");
        if (text === "") text = t === "win98" ? "Close any programs that are using it, and then try again." : "Quit any application that is using it, and try again.";
    } else if (e.code === "exists") {
        title = t === "win98" ? "Error Renaming File" : "That name is already taken.";
    } else if (e.code === "permission") {
        title = t === "win98" ? "Access is denied." : "You do not have enough access privileges for this operation.";
    } else if (e.code === "not-found") {
        title = t === "win98" ? "Cannot find the item." : "The item could not be found.";
    } else {
        title = t === "win98" ? "Desktop" : "The operation could not be completed.";
    }
    return { title: title, text: text, accept: "OK", cancel: "", defaultButton: "accept", icon: t === "win98" ? "error" : "stop", send: null };
}

// ---------------------------------------------------------------- the art

// The 8 generic kinds the Hensou resolver and these icon themes share.
var GENERIC = ["document", "text", "image", "audio", "video", "archive", "application", "folder"];

// What to draw for an icon: { type: "icon", name } (an icon-theme name the
// active theme draws), { type: "file", path } or { type: "lettermark",
// letter, tint, label }. needs: lettermark.js needs().
function artFor(theme, icon, needs) {
    var a = (icon && icon.art) || {};
    var kind = icon ? icon.kind : "";
    // The places: the theme's own art for each, by the icon's kind.
    if (kind === "computer") return { type: "icon", name: "hensou-place-computer" };
    if (kind === "trash") return { type: "icon", name: icon.full === true ? "hensou-place-trash-full" : "hensou-place-trash" };
    if (kind === "volume") return { type: "icon", name: "hensou-place-volume" };
    if (kind === "ssh-hosts") return { type: "icon", name: "hensou-place-network" };
    if (kind === "libraries") return { type: "icon", name: "hensou-place-libraries" };
    if (a.type === "lettermark")
        return { type: "lettermark", letter: String(a.letter || ""), tint: String(a.tint || ""), label: icon.label || "" };
    if (a.type === "themed" && a.path) {
        var path = String(a.path);
        var base = path.replace(/^.*\//, "").replace(/\.(png|svg|xpm)$/, "");
        if (needs && needs(base, path, themeOf(theme)))
            return { type: "lettermark", letter: "", tint: "", label: icon.label || "" };
        return { type: "file", path: path };
    }
    var g = a.type === "generic" ? String(a.kind || "") : "";
    if (g === "computer" || g === "trash" || g === "volume") return artFor(theme, { kind: g, full: icon.full }, needs);
    if (GENERIC.indexOf(g) >= 0) return { type: "icon", name: "hensou-kind-" + g };
    if (kind === "folder") return { type: "icon", name: "hensou-kind-folder" };
    if (kind === "launcher") return { type: "icon", name: "hensou-kind-application" };
    return { type: "icon", name: "hensou-kind-document" };
}

// Platinum shows an alias's name in italics; Memphis draws a shortcut
// arrow over the icon.
function aliasStyle(theme, icon) {
    if (!icon || icon.kind !== "alias") return "";
    return themeOf(theme) === "win98" ? "arrow" : "italic";
}
