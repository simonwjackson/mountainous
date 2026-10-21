// Run notification-model.js, the same file QML loads, without a compositor.
//   node notification-model.test.js notification-model.js ui-socket.v1.json corpus.json [notification-schema.js]
// The schema is packages/notify-sync/schema/ui-socket.v1.json. The corpus is
// written by notification-schema-check.py: lines that the reference
// validator (python jsonschema) labelled valid or invalid.
const fs = require("fs");
const vm = require("vm");
const assert = require("assert");

// Top-level functions and vars land on the context, as QML exposes them.
const model = {};
vm.runInNewContext(fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, ""), model);
const schema = JSON.parse(fs.readFileSync(process.argv[3], "utf8"));
const corpus = JSON.parse(fs.readFileSync(process.argv[4], "utf8"));

// The generated notification-schema.js, which QML imports, carries exactly
// the schema file.
if (process.argv[5]) {
    const generated = {};
    vm.runInNewContext(fs.readFileSync(process.argv[5], "utf8").replace(/^\.pragma library\s*$/m, ""), generated);
    assert.equal(JSON.stringify(generated.schema), JSON.stringify(schema), "notification-schema.js matches the schema");
}

const now = Date.UTC(2026, 9, 20, 12, 0, 0);
const item = (over) => Object.assign({
    id: 1, seq: "myoko-ae370c-1", origin: "local", host: "myoko", app_name: "Firefox",
    app_icon: "firefox", image: null, summary: "Download finished", body: "report.pdf",
    actions: [{key: "default", label: ""}, {key: "open", label: "Open folder"}],
    urgency: 1, resident: false, local_only: false, created: now - 1000, updated: now - 1000,
    sender_alive: true
}, over);
const connectedStatus = {server: "connected", outbox: 0, last_error: null};
const line = (value) => JSON.stringify(value);
const ev = (value) => {
    const parsed = model.parseLine(line(value), schema);
    assert.equal(parsed.kind, "event", line(value) + " " + (parsed.reason || ""));
    return parsed.event;
};
const fold = (events) => events.reduce((s, e) => model.applyEvent(s, ev(e)), model.initialState());

// The validator implements every keyword the schema uses, and refuses a
// schema that uses one it does not.
assert.deepEqual(model.unsupportedKeyword(schema), {kind: "none"});
assert.deepEqual(model.unsupportedKeyword({$defs: {x: {anyOf: []}}}), {kind: "some", value: "anyOf"});
assert.deepEqual(model.unsupportedKeyword({properties: {anyOf: {type: "string"}}}), {kind: "none"},
    "a property named like a keyword is data");

// The parser agrees with the reference validator on every corpus line:
// the fake daemon's whole output, and mutations of it.
assert.ok(corpus.events.length > 50, "the corpus has the daemon's output in it");
let validCount = 0, invalidCount = 0;
for (const entry of corpus.events) {
    const parsed = model.parseLine(entry.line, schema);
    assert.equal(parsed.kind === "event", entry.valid, entry.why + ": " + entry.line.slice(0, 160)
        + (parsed.kind === "invalid" ? " -> " + parsed.reason : ""));
    if (entry.valid) validCount += 1; else invalidCount += 1;
}
assert.ok(validCount > 0 && invalidCount > 0);
for (const entry of corpus.ops) {
    const verdict = model.validate(schema, "clientOperation", JSON.parse(entry.line));
    assert.equal(verdict.kind === "valid", entry.valid, entry.why + ": " + entry.line);
}
// Lines that are not JSON objects never reach the view.
for (const bad of ["", "{", "null", "[]", "42", "\"snapshot\""]) {
    assert.equal(model.parseLine(bad, schema).kind, "invalid", bad);
}
// An invalid line says where it failed.
const missing = model.parseLine(line({type: "upsert", fresh: true, item: Object.assign(item(), {seq: undefined})}), schema);
assert.equal(missing.kind, "invalid");
assert.ok(/seq/.test(missing.reason), missing.reason);
// Every op the view sends is a valid clientOperation.
for (const op of [model.subscribeOp(), model.dismissOp(12), model.actionOp(12, "re\"ply"), model.dismissAllOp()]) {
    assert.deepEqual(model.validate(schema, "clientOperation", JSON.parse(op)), {kind: "valid"}, op);
}
assert.equal(ev({type: "upsert", fresh: false, item: item({sender_alive: false})}).item.sender_alive, false);

// Folding: snapshot, upsert, fresh, remove, status.
let state = fold([
    {type: "snapshot", items: [item({id: 1}), item({id: 2, updated: now})], status: connectedStatus},
]);
assert.deepEqual(state.items.map((i) => i.id), [2, 1], "newest first");
assert.deepEqual(state.popups, [], "a snapshot never pops up");
state = model.applyEvent(state, ev({type: "upsert", fresh: true, item: item({id: 3, updated: now - 5000, urgency: 2})}));
assert.deepEqual(state.items.map((i) => i.id), [3, 2, 1], "critical first");
assert.deepEqual(state.popups, [3]);
state = model.applyEvent(state, ev(({type: "upsert", fresh: false, item: item({id: 1, summary: "edited", updated: now + 1})})));
assert.equal(state.items.length, 3, "an upsert replaces by id");
assert.deepEqual(state.popups, [3], "fresh false does not pop up");
state = model.applyEvent(state, ev(({type: "upsert", fresh: true, item: item({id: 2})})));
state = model.applyEvent(state, ev(({type: "upsert", fresh: true, item: item({id: 3, urgency: 2})})));
assert.deepEqual(state.popups, [3, 2], "a fresh repeat moves to the top, once");
state = model.hidePopup(state, 3);
assert.deepEqual(state.popups, [2]);
assert.equal(state.items.length, 3, "a popup timeout keeps the item");
state = model.applyEvent(state, ev(({type: "remove", id: 2, reason: 2})));
assert.deepEqual(state.items.map((i) => i.id), [3, 1]);
assert.deepEqual(state.popups, []);
state = model.applyEvent(state, ev(({type: "status", status: {server: "unreachable", outbox: 4, last_error: "dial tcp: refused"}})));
assert.equal(state.status.outbox, 4);
const ready = {kind: "ready"};
assert.deepEqual(model.statusBadge(ready, state.status), {kind: "local_only", text: "Local only, 4 queued",
    detail: "New notifications stay on this desktop until the sync server answers. Last error: dial tcp: refused"});
assert.deepEqual(model.statusBadge({kind: "empty"}, {server: "unreachable", outbox: 0, last_error: null}),
    {kind: "local_only", text: "Local only", detail: "New notifications stay on this desktop until the sync server answers."});
assert.deepEqual(model.statusBadge(ready, {server: "connecting", outbox: 0, last_error: null}), {kind: "connecting", text: "Connecting to sync server"});
assert.deepEqual(model.statusBadge(ready, {server: "connecting", outbox: 0, last_error: "x"}), {kind: "connecting", text: "Connecting to sync server"},
    "while it reconnects, notifyd is still trying");
assert.deepEqual(model.statusBadge(ready, {server: "connected", outbox: 9, last_error: null}), {kind: "none"});
// A permanent refusal: connected, nothing queued, an error. Its own state,
// never "Local only", never a promise to retry, with the error in full.
const refused = {server: "connected", outbox: 0, last_error: "HTTP 413: message too large"};
const deliveryError = model.statusBadge(ready, refused);
assert.equal(deliveryError.kind, "delivery_error");
assert.equal(deliveryError.text, "Sync error");
assert.ok(deliveryError.detail.endsWith("Server error: HTTP 413: message too large"), deliveryError.detail);
assert.ok(!/local only|retry|again|queued|until/i.test(deliveryError.text + " " + deliveryError.detail), deliveryError.detail);
assert.equal(model.statusBadge({kind: "empty"}, refused).kind, "delivery_error", "shown with no items too");
assert.equal(model.barTone(ready, refused, [item()]), "warning");
assert.equal(model.barTone(ready, refused, [item({urgency: 2})]), "danger", "an urgent item still outranks it");
assert.equal(model.barText(ready, refused, 3, true), "Notifications 3, sync error");
assert.equal(model.barText(ready, refused, 3, false), "NTF 3");
// Every badge kind the model names is produced above.
assert.deepEqual(Array.from(model.STATUS_BADGE_KINDS).sort(), ["connecting", "delivery_error", "local_only", "none"]);
assert.deepEqual(model.statusBadge({kind: "offline", retryInSeconds: 3}, {server: "unreachable", outbox: 9, last_error: null}), {kind: "none"},
    "a dead socket's status is not shown");
const kept = state.items[1];
state = model.applyEvent(state, ev(({type: "upsert", fresh: false, item: item({id: 3, urgency: 2})})));
assert.strictEqual(state.items[1], kept, "untouched items keep identity, so delegates and scroll survive");
state = model.applyEvent(state, ev(({type: "snapshot", items: [], status: connectedStatus})));
assert.deepEqual(state.items, []);
const many = fold([{type: "snapshot", items: Array.from({length: 500}, (_, i) => item({id: i + 1, updated: now - i})), status: connectedStatus}]);
assert.equal(many.items.length, 500);
assert.equal(many.items[0].id, 1);

// Ops are exactly contract section 7, one line each.
assert.equal(model.subscribeOp(), '{"op":"subscribe"}\n');
assert.equal(model.dismissOp(12), '{"op":"dismiss","id":12}\n');
assert.equal(model.actionOp(12, "re\"ply"), '{"op":"action","id":12,"key":"re\\"ply"}\n');
assert.equal(model.dismissAllOp(), '{"op":"dismiss_all"}\n');
assert.deepEqual([0, 1, 2, 3, 4, 5, 9].map(model.backoffMs), [1000, 2000, 4000, 8000, 16000, 30000, 30000]);

// Readouts.
assert.deepEqual(model.popupTimeout(item({urgency: 2})), {kind: "never"}, "critical does not time out");
assert.deepEqual(model.popupTimeout(item({urgency: 0})), {kind: "after", ms: 4000});
assert.deepEqual(model.popupTimeout(item({urgency: 1})), {kind: "after", ms: 7000});
assert.equal(model.relativeTime(now - 59999, now, 0), "now");
assert.equal(model.relativeTime(now - 60000, now, 0), "1 min");
assert.equal(model.relativeTime(now - 3600000, now, 0), "1 h");
assert.equal(model.relativeTime(now - 86400000 * 2, now, 0), "Oct 18");
assert.equal(model.relativeTime(now + 100000, now, 0), "now");
assert.equal(model.relativeTime(now + 200000, now, 0), "");
assert.equal(model.relativeTime(0, now, 0), "");
// The day is the reader's, from the offset passed in, at both extremes and
// on both sides of local midnight. None of this reads the machine's zone.
const KIRITIMATI = 14 * 60, BAKER = -12 * 60;
assert.equal(model.calendarDay(Date.UTC(2026, 9, 18, 9, 59, 59, 999), KIRITIMATI), "Oct 18", "23:59:59.999 on the 18th");
assert.equal(model.calendarDay(Date.UTC(2026, 9, 18, 10, 0, 0, 0), KIRITIMATI), "Oct 19", "00:00 on the 19th");
assert.equal(model.calendarDay(Date.UTC(2026, 9, 18, 11, 59, 59, 999), BAKER), "Oct 17", "23:59:59.999 on the 17th");
assert.equal(model.calendarDay(Date.UTC(2026, 9, 18, 12, 0, 0, 0), BAKER), "Oct 18", "00:00 on the 18th");
assert.equal(model.calendarDay(Date.UTC(2026, 9, 31, 23, 30), 60), "Nov 1", "a month boundary");
assert.equal(model.calendarDay(Date.UTC(2026, 11, 31, 23, 30), 60), "Jan 1", "a year boundary");
assert.equal(model.relativeTime(Date.UTC(2026, 9, 18, 10, 0), now, KIRITIMATI), "Oct 19");
assert.equal(model.relativeTime(Date.UTC(2026, 9, 18, 10, 0), now, BAKER), "Oct 17");
assert.equal(model.originLabel(item({origin: "remote", host: "hiyori"})), "from hiyori");
assert.equal(model.originLabel(item({origin: "remote", host: ""})), "from another device");
assert.equal(model.originLabel(item()), "");
assert.equal(model.localOnlyLabel(item({local_only: true})), "Only on myoko");
assert.equal(model.localOnlyLabel(item({local_only: true, host: ""})), "Only on this device");
assert.equal(model.appLabel(item({app_name: "", origin: "remote", host: "agent-claude"})), "agent-claude");
assert.equal(model.appLabel(item({app_name: ""})), "Notification");
assert.equal(model.headline(item({summary: "", body: "x"})), "");
assert.equal(model.headline(item({summary: "", body: ""})), "Firefox");
assert.equal(model.buttonLabel({key: "default", label: ""}), "Open");
assert.equal(model.buttonLabel({key: "default", label: "Default"}), "Open");
assert.equal(model.buttonLabel({key: "default", label: "Show tab"}), "Show tab");
assert.equal(model.buttonLabel({key: "snooze", label: ""}), "snooze");
assert.equal(model.defaultAction(item()).kind, "some");
assert.equal(model.defaultAction(item()).value.action.key, "default");
assert.equal(model.defaultAction(item()).value.index, 0);
assert.deepEqual(model.defaultAction(item({actions: [{key: "a", label: "A"}]})), {kind: "none"});
assert.equal(model.enterAction(item({actions: [{key: "a", label: "A"}, {key: "default", label: ""}]})).value.index, 1,
    "Enter prefers the default action");
assert.equal(model.enterAction(item({actions: [{key: "a", label: "A"}]})).value.action.key, "a", "then the first");
assert.deepEqual(model.enterAction(item({actions: []})), {kind: "none"});
assert.deepEqual(model.fileUrl("/tmp/a.png"), {kind: "some", value: "file:///tmp/a.png"});
assert.deepEqual(model.fileUrl("file:///tmp/a.png"), {kind: "some", value: "file:///tmp/a.png"});
assert.deepEqual(model.fileUrl("firefox"), {kind: "none"});
assert.deepEqual(model.fileUrl(null), {kind: "none"});
const found = model.findItem([item({id: 4}), item({id: 5})], 5);
assert.equal(found.kind, "some");
assert.equal(found.value.id, 5);
assert.deepEqual(model.findItem([item({id: 4})], 6), {kind: "none"});
assert.equal(model.itemAt([item({id: 4})], 0).value.id, 4);
assert.deepEqual(model.itemAt([item({id: 4})], 1), {kind: "none"});
assert.deepEqual(model.itemAt([item({id: 4})], -1), {kind: "none"});
// Icons: a path first, then the theme name, then the desktop entry, then
// the letter.
const hit = (url) => () => model.some(url);
const miss = () => model.none();
assert.deepEqual(model.iconChoice(item({app_icon: "/i.png"}), miss, miss), {kind: "image", url: "file:///i.png"});
assert.deepEqual(model.iconChoice(item(), hit("theme"), hit("entry")), {kind: "image", url: "theme"});
assert.deepEqual(model.iconChoice(item(), miss, hit("entry")), {kind: "image", url: "entry"});
assert.deepEqual(model.iconChoice(item(), miss, miss), {kind: "letter", letter: "F"});
assert.deepEqual(model.iconChoice(item({app_icon: "", app_name: ""}), hit("x"), hit("y")), {kind: "letter", letter: "N"});

// Action focus reaches every action, wraps both ways, and Enter follows it.
const twelve = item({actions: Array.from({length: 12}, (_, i) => ({key: "k" + i, label: "Action " + i}))});
let focus = model.noActionFocus();
const visited = [];
for (let i = 0; i < 12; i++) {
    focus = model.moveActionFocus(focus, 12, 1);
    visited.push(focus.index);
}
assert.deepEqual(visited, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
assert.deepEqual(model.moveActionFocus(focus, 12, 1), {kind: "action", index: 0}, "wraps forward");
assert.deepEqual(model.moveActionFocus(model.noActionFocus(), 12, -1), {kind: "action", index: 11}, "back from none lands on the last");
assert.deepEqual(model.moveActionFocus({kind: "action", index: 0}, 12, -1), {kind: "action", index: 11}, "wraps back");
assert.deepEqual(model.moveActionFocus({kind: "action", index: 3}, 0, 1), {kind: "none"}, "no actions, no focus");
assert.equal(model.enterTarget({kind: "action", index: 11}, twelve).value.action.key, "k11");
assert.equal(model.enterTarget(model.noActionFocus(), twelve).value.action.key, "k0");
assert.equal(model.enterTarget({kind: "action", index: 20}, twelve).value.action.key, "k0", "a stale focus falls back");

// The connection: every kind, every input. An input that does not apply
// leaves the state as it is.
const T = 1000000;
const inputs = {
    socketOpened: (c) => model.socketOpened(c),
    snapshotReceived: (c) => model.snapshotReceived(c),
    socketLost: (c) => model.socketLost(c, T),
    snapshotTimedOut: (c) => model.snapshotTimedOut(c, T),
    retryDue: (c) => model.retryDue(c),
    retryNow: (c) => model.retryNow(c),
};
const sample = {
    connecting: {kind: "connecting", attempt: 2},
    awaiting_snapshot: {kind: "awaiting_snapshot", attempt: 2},
    connected: {kind: "connected"},
    offline: {kind: "offline", attempt: 3, retryAt: T + 4000},
};
const expected = {
    connecting: {
        socketOpened: {kind: "awaiting_snapshot", attempt: 2},
        socketLost: {kind: "offline", attempt: 3, retryAt: T + 4000},
    },
    awaiting_snapshot: {
        snapshotReceived: {kind: "connected"},
        socketLost: {kind: "offline", attempt: 3, retryAt: T + 4000},
        snapshotTimedOut: {kind: "offline", attempt: 3, retryAt: T + 4000},
        retryNow: {kind: "connecting", attempt: 0},
    },
    connected: {
        snapshotReceived: {kind: "connected"},
        socketLost: {kind: "offline", attempt: 1, retryAt: T + 1000},
    },
    offline: {
        retryDue: {kind: "connecting", attempt: 3},
        retryNow: {kind: "connecting", attempt: 0},
    },
};
assert.deepEqual(Object.keys(sample), Array.from(model.CONNECTION_KINDS), "the test covers every kind the model has");
for (const kind of model.CONNECTION_KINDS) {
    for (const [name, apply] of Object.entries(inputs)) {
        const want = (expected[kind] || {})[name];
        const got = apply(sample[kind]);
        if (want) assert.deepEqual(got, want, kind + " + " + name);
        else assert.strictEqual(got, sample[kind], kind + " + " + name + " changes nothing");
    }
}
assert.deepEqual(model.connectionStart(), {kind: "connecting", attempt: 0});
// The backoff grows through repeated failures and resets on a snapshot.
let conn = model.connectionStart();
const delays = [];
for (let i = 0; i < 7; i++) {
    conn = model.socketLost(conn, 0);
    delays.push(conn.retryAt);
    conn = model.retryDue(conn);
}
assert.deepEqual(delays, [1000, 2000, 4000, 8000, 16000, 30000, 30000]);
conn = model.snapshotReceived(model.socketOpened(conn));
assert.deepEqual(model.socketLost(conn, 0), {kind: "offline", attempt: 1, retryAt: 1000});

// The view: one tagged value per connection and item count.
assert.deepEqual(model.viewState({kind: "offline", attempt: 1, retryAt: T + 1500}, [], T), {kind: "offline", retryInSeconds: 2});
assert.deepEqual(model.viewState({kind: "offline", attempt: 1, retryAt: T - 5}, [], T), {kind: "offline", retryInSeconds: 0});
assert.deepEqual(model.viewState(sample.connecting, [item()], T), {kind: "connecting"});
assert.deepEqual(model.viewState(sample.awaiting_snapshot, [item()], T), {kind: "connecting"});
assert.deepEqual(model.viewState(sample.connected, [], T), {kind: "empty"});
assert.deepEqual(model.viewState(sample.connected, [item()], T), {kind: "ready"});
assert.deepEqual(Array.from(model.VIEW_KINDS).sort(),
    ["connecting", "empty", "offline", "ready"], "every view kind is reachable above");

const up = {server: "connected", outbox: 0, last_error: null};
const off = {kind: "offline", retryInSeconds: 2};
assert.equal(model.barText(off, up, 3, false), "NTF !");
assert.equal(model.barText(off, up, 3, true), "Notifications offline");
assert.equal(model.barText({kind: "connecting"}, up, 3, false), "NTF");
assert.equal(model.barText({kind: "empty"}, up, 0, false), "NTF");
assert.equal(model.barText(ready, up, 12, false), "NTF 12");
assert.equal(model.barText(ready, {server: "unreachable", outbox: 2, last_error: null}, 12, true), "Notifications 12, local only");
assert.equal(model.barTone(off, up, [item({urgency: 2})]), "warning", "a dead socket outranks an urgent item");
assert.equal(model.barTone({kind: "connecting"}, up, []), "muted");
assert.equal(model.barTone(ready, {server: "unreachable", outbox: 0, last_error: null}, [item({urgency: 2})]), "danger");
assert.equal(model.barTone(ready, {server: "unreachable", outbox: 0, last_error: null}, [item()]), "warning");
assert.equal(model.barTone(ready, up, [item()]), "primary");
assert.equal(model.barTone({kind: "empty"}, up, []), "muted");

// Layout plans: one unit either side of every threshold.
const cp = (w) => model.cardPlan(w, true, false);
assert.equal(cp(299).metaInline, false);
assert.equal(cp(300).metaInline, true);
assert.equal(cp(299).imageBelow, true);
assert.equal(cp(300).imageSide, true);
assert.equal(model.cardPlan(300, false, false).imageSide, false);
assert.equal(model.cardPlan(1000, true, true).metaInline, false, "an open card gives host and time their own line");
assert.equal(model.cardPlan(1000, true, true).imageBelow, true, "an open card shows the whole image below");
assert.equal(cp(259).padding, 8);
assert.equal(cp(260).padding, 10);
assert.equal(cp(380).imageSize, 61);
assert.equal(cp(1000).imageSize, 64);
assert.equal(cp(0).inner, 0);
assert.ok(cp(120).buttonMaxWidth > 0, "a button always has room for its wrapped label");

const c = model.centrePlan;
assert.equal(c(1920, 1200).cardWidth, 440);
assert.equal(c(200, 1200).cardWidth, 188);
assert.equal(c(0, 0).cardWidth, 0);
assert.equal(c(0, 0).maxHeight, 0);
assert.equal(c(371, 1200).badgeOwnRow, true);
assert.equal(c(372, 1200).badgeOwnRow, false);
assert.equal(c(311, 1200).dismissAllLabel, "All");
assert.equal(c(312, 1200).dismissAllLabel, "Dismiss all");
assert.equal(c(1920, 437).showHint, false);
assert.equal(c(1920, 438).showHint, true);
assert.equal(c(1920, 637).bodyLines, 3);
assert.equal(c(1920, 638).bodyLines, 6);
assert.equal(c(1920, 397).padding, 8);
assert.equal(c(1920, 398).padding, 12);
// Dismiss all and close are in every plan: no field can turn them off.
for (const [w, h] of [[1920, 1200], [960, 1200], [480, 1000], [1920, 360], [200, 200]]) {
    const plan = c(w, h);
    assert.ok(plan.dismissAllLabel.length > 0);
    assert.ok(!("showDismissAll" in plan) && !("showClose" in plan));
}

const p = model.popupPlan(1920, 1200);
assert.equal(p.cardWidth, 380);
assert.equal(p.maxHeight, 1162);
assert.equal(model.popupPlan(300, 1200).cardWidth, 288);
assert.equal(model.popupPlan(1920, 445).bodyLines, 2);
assert.equal(model.popupPlan(1920, 446).bodyLines, 3);
const fit = (heights, room) => model.fitPopups(heights, room, 6, 30, 4);
assert.deepEqual(fit([], 1000), {visible: 0, hidden: 0});
assert.deepEqual(fit([100], 10), {visible: 1, hidden: 0}, "the newest always shows");
assert.deepEqual(fit([100, 100], 206), {visible: 2, hidden: 0});
assert.deepEqual(fit([100, 100], 205), {visible: 1, hidden: 1});
assert.deepEqual(fit([100, 100, 100], 242), {visible: 2, hidden: 1}, "two cards and the chip");
assert.deepEqual(fit([100, 100, 100], 241), {visible: 1, hidden: 2});
assert.deepEqual(fit([100, 100, 100, 100, 100, 100], 5000), {visible: 4, hidden: 2}, "at most four");
assert.deepEqual(fit([100, 100, 100, 100], 5000), {visible: 4, hidden: 0});

console.log("notification-view model: parse, fold, ops, backoff, readouts, card/centre/popup plans passed");
