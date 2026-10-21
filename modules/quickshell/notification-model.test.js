// Run notification-model.js, the same file QML loads, without a compositor.
//   node notification-model.test.js notification-model.js
const fs = require("fs");
const vm = require("vm");
const assert = require("assert");

const names = [
    "parseLine", "applyEvent", "initialState", "sortItems", "hidePopup", "normaliseItem",
    "subscribeOp", "dismissOp", "actionOp", "dismissAllOp", "backoffMs", "popupTimeoutMs",
    "relativeTime", "calendarDay", "appLabel", "originLabel", "localOnlyLabel", "headline", "buttonLabel",
    "defaultAction", "fileUrl", "barText", "serverBadge", "popupPlan", "fitPopups",
    "centrePlan", "cardPlan"
];
const model = {};
vm.runInNewContext(
    fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, "")
        + "\nObject.assign(model, {" + names.join(", ") + "});",
    {model});

const now = Date.UTC(2026, 9, 20, 12, 0, 0);
const item = (over) => Object.assign({
    id: 1, seq: "myoko-ae370c-1", origin: "local", host: "myoko", app_name: "Firefox",
    app_icon: "firefox", image: null, summary: "Download finished", body: "report.pdf",
    actions: [{key: "default", label: ""}, {key: "open", label: "Open folder"}],
    urgency: 1, resident: false, local_only: false, created: now - 1000, updated: now - 1000,
    sender_alive: true
}, over);
const line = (value) => JSON.stringify(value);
const fold = (events) => events.reduce((s, e) => model.applyEvent(s, model.parseLine(line(e))), model.initialState());

// Parsing: malformed lines and items never reach the view.
for (const bad of ["", "{", "null", "[]", "42", line({type: "nope"}), line({type: "upsert", item: {summary: "no id"}}),
    line({type: "remove"}), line({type: "upsert", item: item({id: "7"})})]) {
    assert.equal(model.parseLine(bad), null, bad);
}
const parsed = model.parseLine(line({type: "upsert", fresh: true, item: {id: 9, urgency: 7, actions: [{key: ""}, {key: "x"}, null]}}));
assert.equal(parsed.item.urgency, 2);
assert.deepEqual(parsed.item.actions, [{key: "x", label: ""}]);
assert.equal(parsed.item.sender_alive, true, "missing sender_alive is not a dead sender");
assert.equal(parsed.item.image, null);
assert.equal(model.parseLine(line({type: "upsert", item: item({sender_alive: false})})).item.sender_alive, false);
assert.deepEqual(model.parseLine(line({type: "status", status: {server: "weird", outbox: -3}})).status,
    {server: "connecting", outbox: 0, last_error: null});

// Folding: snapshot, upsert, fresh, remove, status.
let state = fold([
    {type: "snapshot", items: [item({id: 1}), item({id: 2, updated: now})], status: {server: "connected", outbox: 0, last_error: null}},
]);
assert.deepEqual(state.items.map((i) => i.id), [2, 1], "newest first");
assert.deepEqual(state.popups, [], "a snapshot never pops up");
state = model.applyEvent(state, model.parseLine(line({type: "upsert", fresh: true, item: item({id: 3, updated: now - 5000, urgency: 2})})));
assert.deepEqual(state.items.map((i) => i.id), [3, 2, 1], "critical first");
assert.deepEqual(state.popups, [3]);
state = model.applyEvent(state, model.parseLine(line({type: "upsert", fresh: false, item: item({id: 1, summary: "edited", updated: now + 1})})));
assert.equal(state.items.length, 3, "an upsert replaces by id");
assert.deepEqual(state.popups, [3], "fresh false does not pop up");
state = model.applyEvent(state, model.parseLine(line({type: "upsert", fresh: true, item: item({id: 2})})));
state = model.applyEvent(state, model.parseLine(line({type: "upsert", fresh: true, item: item({id: 3, urgency: 2})})));
assert.deepEqual(state.popups, [3, 2], "a fresh repeat moves to the top, once");
state = model.hidePopup(state, 3);
assert.deepEqual(state.popups, [2]);
assert.equal(state.items.length, 3, "a popup timeout keeps the item");
state = model.applyEvent(state, model.parseLine(line({type: "remove", id: 2, reason: 2})));
assert.deepEqual(state.items.map((i) => i.id), [3, 1]);
assert.deepEqual(state.popups, []);
state = model.applyEvent(state, model.parseLine(line({type: "status", status: {server: "unreachable", outbox: 4, last_error: "dial tcp: refused"}})));
assert.equal(state.status.outbox, 4);
assert.equal(model.serverBadge(state.status), "Local only, 4 queued");
assert.equal(model.serverBadge({server: "unreachable", outbox: 0}), "Local only");
assert.equal(model.serverBadge({server: "connected", outbox: 9}), "");
const kept = state.items[1];
state = model.applyEvent(state, model.parseLine(line({type: "upsert", fresh: false, item: item({id: 3, urgency: 2})})));
assert.strictEqual(state.items[1], kept, "untouched items keep identity, so delegates and scroll survive");
state = model.applyEvent(state, model.parseLine(line({type: "snapshot", items: [], status: {server: "connected", outbox: 0}})));
assert.deepEqual(state.items, []);
const many = fold([{type: "snapshot", items: Array.from({length: 500}, (_, i) => item({id: i + 1, updated: now - i})), status: {}}]);
assert.equal(many.items.length, 500);
assert.equal(many.items[0].id, 1);

// Ops are exactly contract section 7, one line each.
assert.equal(model.subscribeOp(), '{"op":"subscribe"}\n');
assert.equal(model.dismissOp(12), '{"op":"dismiss","id":12}\n');
assert.equal(model.actionOp(12, "re\"ply"), '{"op":"action","id":12,"key":"re\\"ply"}\n');
assert.equal(model.dismissAllOp(), '{"op":"dismiss_all"}\n');
assert.deepEqual([0, 1, 2, 3, 4, 5, 9].map(model.backoffMs), [1000, 2000, 4000, 8000, 16000, 30000, 30000]);

// Readouts.
assert.equal(model.popupTimeoutMs(item({urgency: 2})), 0, "critical does not time out");
assert.equal(model.popupTimeoutMs(item({urgency: 0})), 4000);
assert.equal(model.popupTimeoutMs(item({urgency: 1})), 7000);
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
assert.equal(model.defaultAction(item()).key, "default");
assert.equal(model.defaultAction(item({actions: []})), null);
assert.equal(model.fileUrl("/tmp/a.png"), "file:///tmp/a.png");
assert.equal(model.fileUrl("file:///tmp/a.png"), "file:///tmp/a.png");
assert.equal(model.fileUrl("firefox"), "");
const up = {server: "connected", outbox: 0};
assert.equal(model.barText(false, false, up, 3, false), "NTF !");
assert.equal(model.barText(false, false, up, 3, true), "Notifications offline");
assert.equal(model.barText(false, true, up, 3, false), "NTF");
assert.equal(model.barText(true, false, up, 0, false), "NTF");
assert.equal(model.barText(true, false, up, 12, false), "NTF 12");
assert.equal(model.barText(true, false, {server: "unreachable", outbox: 2}, 12, true), "Notifications 12, local only");

// Layout plans: one unit either side of every threshold.
const cp = (w) => model.cardPlan(w, true);
assert.equal(cp(299).metaInline, false);
assert.equal(cp(300).metaInline, true);
assert.equal(cp(299).imageBelow, true);
assert.equal(cp(300).imageSide, true);
assert.equal(model.cardPlan(300, false).imageSide, false);
assert.equal(cp(259).padding, 8);
assert.equal(cp(260).padding, 10);
assert.equal(cp(380).imageSize, 61);
assert.equal(cp(1000).imageSize, 64);
assert.equal(cp(0).inner, 0);
assert.ok(cp(120).buttonMaxWidth > 0, "a button always has room for an elided label");

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
