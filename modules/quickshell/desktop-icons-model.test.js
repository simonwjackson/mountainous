// desktop-icons-model.js: the provider session (resubscribe on a display
// or theme change, hide on loss), selection, keyboard navigation, drag and
// drop, menus, the confirmation each theme asks for, and the art.
// Run: node desktop-icons-model.test.js [desktop-icons-model.js] [lettermark.js]
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
function load(file) {
    const o = {};
    vm.runInNewContext(fs.readFileSync(file, "utf8").replace(/^\.pragma library\s*$/m, ""), o);
    return o;
}
const M = load(process.argv[2] || __dirname + "/desktop-icons-model.js");
const L = load(process.argv[3] || __dirname + "/lettermark.js");
const plain = (x) => (x === undefined ? x : JSON.parse(JSON.stringify(x)));
const same = (a, b, m) => assert.deepEqual(plain(a), plain(b), m);

// ---- fixtures: the stub's icons (hensou-desktop-stub)
function icon(id, kind, label, generic, row, extra) {
    return Object.assign({ id, kind, label, art: { type: "generic", kind: generic, path: "" },
        position: { x: 16, y: 16 + row * 72 }, available: true, reason: null,
        full: kind === "trash" ? true : null, ejectable: kind === "volume" ? true : null }, extra || {});
}
const icons = [
    icon("computer", "computer", "Myoko", "computer", 0),
    icon("ssh-hosts", "ssh-hosts", "SSH Hosts", "folder", 1),
    icon("trash", "trash", "Trash", "trash", 2),
    icon("file:notes.txt", "file", "notes.txt", "text", 3),
    icon("file:Projects", "folder", "Projects", "folder", 4),
    icon("file:krita.desktop", "launcher", "Krita", "application", 5, { art: { type: "lettermark", letter: "K", tint: "#3a6ea5" } }),
    icon("file:Docs link", "alias", "Docs link", "folder", 6),
    icon("volume:sdb1", "volume", "USB", "volume", 7),
];
const line = (m) => JSON.stringify(m);

// ---- the screen layout
const screen = { name: "eDP-1", width: 1920, height: 1200, scale: 1.5 };
const pl = M.screenLayout("platinum", screen);
same(plain(pl), { output: "eDP-1", width: 1920, height: 1200, scale: 1.5, usable: { x: 0, y: 28, width: 1920, height: 1130 } });
const wl = M.screenLayout("memphis", screen);
// 28 u at 1.5 is 37.3 logical px; the taskbar's zone rounds up to 38.
same(plain(wl.usable), { x: 0, y: 0, width: 1920, height: 1162 });
assert.equal(M.screenLayout("memphis", Object.assign({}, screen, { scale: 1 })).usable.height, 1200 - 56);

// ---- the session
function run(state, events) {
    let s = state, sent = [], effects = [];
    for (const e of events) {
        const r = M.reduce(s, e);
        s = r.state; sent = sent.concat(plain(r.send)); effects = effects.concat(plain(r.effects));
    }
    return { s, sent, effects };
}
let r = run(M.initial(), [{ type: "connect" }]);
assert.equal(r.s.kind, "connecting");
same(r.effects, [{ type: "open-socket" }]);
r = run(r.s, [{ type: "opened" }]);
same(r.sent, [{ type: "hello", major: 1, minor: 0 }]);
// Hello answered before the shell knows its screen: it waits for one.
r = run(r.s, [{ type: "line", data: line({ type: "hello", major: 1, minor: 0 }) }]);
assert.equal(r.s.kind, "waiting-layout");
same(r.sent, []);
r = run(r.s, [{ type: "layout", theme: "platinum", layout: pl }]);
assert.equal(r.s.kind, "subscribing");
same(r.sent, [{ type: "subscribe", theme: "platinum", screen: plain(pl) }]);
assert.equal(M.shown(r.s), false, "nothing drawn before the snapshot");
const reversed = run(r.s, [{ type: "line", data: line({ type: "snapshot", icons: icons.slice().reverse(), snap: false, grid: { cell_width: 80, cell_height: 72 } }) }]);
same(reversed.s.icons.map((i) => i.id), icons.slice().reverse().map((i) => i.id), "the snapshot's order, not the screen's");
r = run(r.s, [{ type: "line", data: line({ type: "snapshot", icons, snap: false, grid: { cell_width: 80, cell_height: 72 } }) }]);
assert.equal(r.s.kind, "live");
assert.equal(M.shown(r.s), true);
let live = r.s;

// Layout first, then Hello: the Hello answer subscribes at once.
r = run(M.initial(), [{ type: "layout", theme: "memphis", layout: wl }, { type: "connect" }, { type: "opened" },
    { type: "line", data: line({ type: "hello", major: 1, minor: 3 }) }]);
assert.equal(r.s.kind, "subscribing");
same(r.sent.map((m) => m.type), ["hello", "subscribe"]);
assert.equal(r.sent[1].theme, "memphis");

// Changed: upserts by id, then removals.
r = run(live, [{ type: "line", data: line({ type: "changed",
    upsert: [Object.assign({}, icons[3], { position: { x: 400, y: 16 } }), icon("file:new.png", "file", "new.png", "image", 9)],
    removed: ["file:Projects"] }) }]);
same(r.s.icons[3], Object.assign({}, icons[3], { position: { x: 400, y: 16 } }), "updated in place");
assert.equal(r.s.icons[r.s.icons.length - 1].id, "file:new.png", "new icons at the end");
assert.ok(!r.s.icons.some((i) => i.id === "file:Projects"));
assert.ok(r.s.icons.some((i) => i.id === "file:new.png"));
assert.equal(r.s.icons.length, icons.length);
// Snap and garbage lines.
r = run(live, [{ type: "line", data: line({ type: "snap", snap: true }) }, { type: "line", data: "not json" }, { type: "line", data: "" }]);
assert.equal(r.s.snap, true);
assert.equal(r.s.kind, "live");

// Resubscribe on a display change and on a theme switch; not for the same layout.
r = run(live, [{ type: "layout", theme: "platinum", layout: pl }]);
same(r.sent, [], "same layout: no resubscribe");
const external = M.screenLayout("platinum", { name: "DP-1", width: 2560, height: 1440, scale: 1 });
r = run(live, [{ type: "layout", theme: "platinum", layout: external }]);
same(r.sent, [{ type: "subscribe", theme: "platinum", screen: plain(external) }]);
assert.equal(r.s.kind, "subscribing");
assert.equal(M.shown(r.s), true, "the provider's icons stay while it answers");
const rotated = M.screenLayout("platinum", { name: "eDP-1", width: 1200, height: 1920, scale: 1.5 });
assert.equal(run(live, [{ type: "layout", theme: "platinum", layout: rotated }]).sent.length, 1);
const rescaled = M.screenLayout("platinum", { name: "eDP-1", width: 1920, height: 1200, scale: 1.25 });
assert.equal(run(live, [{ type: "layout", theme: "platinum", layout: rescaled }]).sent.length, 1);
r = run(live, [{ type: "layout", theme: "memphis", layout: wl }]);
same(r.sent, [{ type: "subscribe", theme: "memphis", screen: plain(wl) }]);
// The fresh snapshot replaces the icons (Memphis has no volume on the desktop).
r = run(r.s, [{ type: "line", data: line({ type: "snapshot", icons: icons.slice(0, 7), snap: true, grid: { cell_width: 75, cell_height: 75 } }) }]);
assert.equal(r.s.icons.length, 7);
assert.equal(r.s.grid.cell_width, 75);

// The provider goes away: icons hide at once, quiet retries back off.
r = run(live, [{ type: "lost" }]);
assert.equal(r.s.kind, "down");
assert.equal(M.shown(r.s), false);
same(r.s.icons, []);
same(r.effects, [{ type: "close-socket" }, { type: "retry", ms: 500 }]);
assert.ok(!r.effects.some((e) => e.type === "error"), "no alert while down");
let waits = [];
let s = live;
for (let i = 0; i < 7; i++) {
    const x = run(s, [{ type: "lost" }]);
    waits.push(x.effects.find((e) => e.type === "retry").ms);
    s = run(x.s, [{ type: "retry" }, { type: "opened" }]).s;
}
same(waits, [500, 1000, 2000, 4000, 8000, 8000, 8000]);
// A lost socket before the snapshot does not show icons when it comes back.
s = run(s, [{ type: "line", data: line({ type: "hello", major: 1, minor: 0 }) }]).s;
assert.equal(s.kind, "subscribing", "the remembered layout subscribes again");
assert.equal(M.shown(s), false);
s = run(s, [{ type: "line", data: line({ type: "snapshot", icons, snap: false, grid: { cell_width: 80, cell_height: 72 } }) }]).s;
assert.equal(s.attempts, 0, "a good hello resets the backoff");
// Messages for a dead session are ignored.
assert.equal(run(M.initial(), [{ type: "line", data: line({ type: "snapshot", icons, snap: false }) }]).s.kind, "down");
// Another major version: closed, retried slowly, never shown.
r = run(M.initial(), [{ type: "connect" }, { type: "opened" }, { type: "line", data: line({ type: "hello", major: 2, minor: 0 }) }]);
assert.equal(r.s.kind, "refused");
same(r.effects.slice(-2), [{ type: "close-socket" }, { type: "retry", ms: 30000 }]);
r = run(M.initial(), [{ type: "connect" }, { type: "opened" }, { type: "line", data: line({ type: "error", code: "version", message: "x", ids: [] }) }]);
assert.equal(r.s.kind, "refused");
// ConfirmNeeded and Error reach the shell as effects.
r = run(live, [{ type: "line", data: line({ type: "confirm-needed", request: 4, ids: ["file:notes.txt"], confirmation: { type: "move-to-trash", count: 1 } }) },
    { type: "line", data: line({ type: "error", code: "busy", message: "The volume is in use by ghostty.", ids: ["volume:sdb1"] }) }]);
same(r.effects.map((e) => e.type), ["confirm", "error"]);
assert.equal(r.effects[0].request, 4);
assert.equal(r.effects[1].code, "busy");
assert.equal(M.encode({ type: "open", ids: ["trash"] }), '{"type":"open","ids":["trash"]}\n');

// ---- selection
let c = M.click("platinum", icons, [], "", "trash", {});
same(plain(c), { selection: ["trash"], anchor: "trash" });
c = M.click("platinum", icons, c.selection, c.anchor, "computer", { shift: true });
same(plain(c.selection), ["trash", "computer"], "Platinum: Shift adds");
c = M.click("platinum", icons, c.selection, c.anchor, "trash", { shift: true });
same(plain(c.selection), ["computer"], "Platinum: Shift removes");
c = M.click("memphis", icons, ["trash"], "trash", "computer", { ctrl: true });
same(plain(c.selection), ["trash", "computer"], "Memphis: Ctrl adds");
c = M.click("memphis", icons, ["computer"], "computer", "file:notes.txt", { shift: true });
same(plain(c.selection), ["computer", "ssh-hosts", "trash", "file:notes.txt"], "Memphis: Shift selects the run");
c = M.click("memphis", icons, ["file:notes.txt"], "file:notes.txt", "computer", { shift: true });
same(plain(c.selection), ["computer", "ssh-hosts", "trash", "file:notes.txt"]);
// A plain press on a selected icon keeps the group for a drag; release narrows it.
c = M.click("platinum", icons, ["trash", "computer"], "trash", "computer", {});
same(plain(c.selection), ["trash", "computer"]);
same(plain(M.release(c.selection, "computer", {}, false)), ["computer"]);
same(plain(M.release(c.selection, "computer", {}, true)), ["trash", "computer"]);

// Boxes as DesktopIcons.qml measures them: image and label rects.
const boxes = icons.map((i) => ({ id: i.id, rects: [
    { x: i.position.x + 24, y: 28 + i.position.y + 2, w: 32, h: 32 },
    { x: i.position.x + 10, y: 28 + i.position.y + 38, w: 60, h: 16 }] }));
// A band over rows 1 to 3 only.
same(plain(M.bandSelection(boxes, M.band(60, 130, 0, 290), [], false)), ["ssh-hosts", "trash", "file:notes.txt"]);
same(plain(M.bandSelection(boxes, M.band(0, 130, 60, 160), ["volume:sdb1"], true)), ["volume:sdb1", "ssh-hosts"]);
same(plain(M.bandSelection(boxes, M.band(500, 500, 600, 600), ["trash"], false)), []);
same(plain(M.bandSelection(boxes, M.band(500, 500, 600, 600), ["trash"], true)), ["trash"]);

// ---- keyboard navigation
assert.equal(M.neighbour(boxes, "", "down"), "computer", "nothing selected: the first icon");
assert.equal(M.neighbour(boxes, "computer", "down"), "ssh-hosts");
assert.equal(M.neighbour(boxes, "ssh-hosts", "up"), "computer");
assert.equal(M.neighbour(boxes, "computer", "up"), "computer", "nothing above: stay");
assert.equal(M.neighbour(boxes, "computer", "right"), "computer");
assert.equal(M.neighbour(boxes, "volume:sdb1", "down"), "volume:sdb1");
// A second column: right goes across the row, not down the column.
const grid2 = boxes.concat([{ id: "b", rects: [{ x: 120, y: 28 + 16 + 72 * 2 + 2, w: 32, h: 32 }] },
    { id: "far", rects: [{ x: 900, y: 28 + 16 + 2, w: 32, h: 32 }] }]);
assert.equal(M.neighbour(grid2, "trash", "right"), "b");
assert.equal(M.neighbour(grid2, "b", "left"), "trash");
assert.equal(M.neighbour(grid2, "computer", "right"), "far");
assert.equal(M.edge(boxes, false), "computer");
assert.equal(M.edge(boxes, true), "volume:sdb1");
assert.equal(M.edge([], true), "");
assert.equal(M.byLetter(icons, "", "p"), "file:Projects");
assert.equal(M.byLetter(icons, "", "s"), "ssh-hosts");
assert.equal(M.byLetter(icons, "ssh-hosts", "S"), "ssh-hosts", "one match stays");
assert.equal(M.byLetter(icons, "", "d"), "file:Docs link");
assert.equal(M.byLetter(icons, "file:Projects", "z"), "file:Projects");

// ---- overlapping icons: the provider cascades what the grid cannot hold
// 12 px apart, and two may sit on one spot. Every icon stays reachable.
const cascade = [icon("a", "file", "a.txt", "text", 0), icon("b", "file", "b.txt", "text", 0),
    icon("c", "file", "c.txt", "text", 0), icon("d", "file", "d.txt", "text", 0), icon("e", "file", "e.txt", "text", 1)];
cascade[1].position = { x: 28, y: 28 };
cascade[2].position = { x: 40, y: 40 };
cascade[3].position = { x: 40, y: 40 };   // exactly under c
const cboxes = cascade.map((i) => ({ id: i.id, rects: [{ x: i.position.x + 24, y: i.position.y + 2, w: 32, h: 32 }] }));
// Tab and Shift+Tab walk the snapshot's order and cycle.
const tabs = [];
for (let id = "", k = 0; k < 6; k++) { id = M.tabNext(cascade, id, false); tabs.push(id); }
same(tabs, ["a", "b", "c", "d", "e", "a"]);
{
    const back = [];
    for (let id = "", k = 0; k < 5; k++) { id = M.tabNext(cascade, id, true); back.push(id); }
    same(back, ["e", "d", "c", "b", "a"]);
}
assert.equal(M.tabNext([], "", false), "");
assert.equal(M.tabNext(cascade, "gone", false), "a");
// Arrows reach the covered ones: down the cascade, and onto an icon
// stacked exactly under another in the provider's order.
assert.equal(M.neighbour(cboxes, "a", "down"), "b");
assert.equal(M.neighbour(cboxes, "b", "right"), "c");
assert.equal(M.neighbour(cboxes, "c", "down"), "d", "the icon under c");
assert.equal(M.neighbour(cboxes, "d", "up"), "c");
assert.equal(M.neighbour(cboxes, "c", "up"), "b");
const reached = new Set();
for (const start of ["a", "e"]) for (const dir of ["down", "right", "up", "left"]) {
    let id = start;
    for (let k = 0; k < 8; k++) { reached.add(id); id = M.neighbour(cboxes, id, dir); }
}
same([...reached].sort(), ["a", "b", "c", "d", "e"], "arrows reach every icon");
// The selected icons stack above the rest, the focused one above all.
const z = (id, sel, focus) => M.zFor(cascade, id, sel, focus);
assert.ok(z("b", [], "") > z("a", [], ""), "the provider's order stacks");
assert.ok(z("a", ["a"], "") > z("d", [], ""), "a selected icon rises over the cascade");
assert.ok(z("d", ["a", "d"], "d") > z("a", ["a", "d"], "d"), "the focused one is on top");
assert.ok(z("c", ["c"], "d") < z("d", ["c"], "d"));
const zs = cascade.map((i) => z(i.id, ["b"], "a"));
assert.equal(Math.max(...zs), z("a", ["b"], "a"));
assert.equal(new Set(zs).size, zs.length, "no two icons share a z");
// A band and a click hit the covered icon too.
same(M.bandSelection(cboxes, M.band(86, 63, 95, 73), [], false), ["c", "d"]);

// ---- drag and drop
const trashBox = boxes.find((b) => b.id === "trash").rects[0];
assert.equal(M.dropTarget(icons, boxes, trashBox.x + 5, trashBox.y + 5, ["file:notes.txt"]), "trash");
assert.equal(M.dropTarget(icons, boxes, trashBox.x + 5, trashBox.y + 5, ["trash"]), "", "not onto itself");
const compBox = boxes.find((b) => b.id === "computer").rects[0];
assert.equal(M.dropTarget(icons, boxes, compBox.x + 5, compBox.y + 5, ["file:notes.txt"]), "", "the computer takes no drop");
const usbBox = boxes.find((b) => b.id === "volume:sdb1").rects[1];
assert.equal(M.dropTarget(icons, boxes, usbBox.x + 1, usbBox.y + 1, ["file:notes.txt"]), "volume:sdb1");
assert.equal(M.dropTarget(icons, boxes, 1500, 900, ["file:notes.txt"]), "");
let end = M.endDrag(icons, ["file:notes.txt", "file:Projects"], "", 200, 10, pl.usable, { cell_width: 80, cell_height: 72 });
same(plain(end), { type: "move", moves: [["file:notes.txt", { x: 216, y: 242 }], ["file:Projects", { x: 216, y: 314 }]] });
end = M.endDrag(icons, ["file:notes.txt"], "", -500, 5000, pl.usable, { cell_width: 80, cell_height: 72 });
same(plain(end.moves), [["file:notes.txt", { x: 0, y: 1130 - 72 }]], "kept inside the usable area");
same(plain(M.endDrag(icons, ["file:notes.txt"], "trash", 3, 3, pl.usable)), { type: "drop", ids: ["file:notes.txt"], target: "trash" });
assert.equal(M.endDrag(icons, ["file:notes.txt"], "", 0, 0, pl.usable), null);
assert.equal(M.endDrag(icons, [], "trash", 9, 9, pl.usable), null);

// ---- rename
const notes = icons[3];
assert.equal(M.renameTo(notes, " todo.txt "), "todo.txt");
assert.equal(M.renameTo(notes, "notes.txt"), "");
assert.equal(M.renameTo(notes, ""), "");
assert.equal(M.renameTo(notes, "a/b"), "");
assert.equal(M.canRename(icons[0]), false, "the computer keeps its name");
assert.equal(M.canRename(icons[2]), false);
assert.equal(M.canRename(icons[7]), false);

// ---- menus
const labels = (rows) => rows.map((r) => (r.separator ? "-" : r.label + (r.disabled ? " (off)" : "") + (r.checked ? " ✓" : "")));
same(labels(M.iconMenu("platinum", icons, ["file:notes.txt"], "file:notes.txt")), ["Open", "Move to Trash", "-", "Rename"]);
same(labels(M.iconMenu("memphis", icons, ["file:notes.txt"], "file:notes.txt")), ["&Open", "-", "&Delete", "Rena&me"]);
same(labels(M.iconMenu("platinum", icons, ["trash"], "trash")), ["Open", "Empty Trash…"]);
same(labels(M.iconMenu("memphis", icons, ["trash"], "trash")), ["&Open", "-", "Empty Recycle &Bin"]);
const emptyTrash = icons.map((i) => (i.id === "trash" ? Object.assign({}, i, { full: false }) : i));
same(labels(M.iconMenu("platinum", emptyTrash, ["trash"], "trash")), ["Open", "Empty Trash… (off)"]);
same(labels(M.iconMenu("platinum", icons, ["volume:sdb1"], "volume:sdb1")), ["Open", "Eject"]);
same(labels(M.iconMenu("memphis", icons, ["volume:sdb1"], "volume:sdb1")), ["&Open", "-", "&Eject"]);
same(labels(M.iconMenu("platinum", icons, ["computer"], "computer")), ["Open"]);
// Several selected: Move to Trash only when all can go; Rename off.
same(labels(M.iconMenu("platinum", icons, ["file:notes.txt", "file:Projects"], "file:notes.txt")), ["Open", "Move to Trash", "-", "Rename (off)"]);
same(labels(M.iconMenu("platinum", icons, ["file:notes.txt", "trash"], "file:notes.txt")), ["Open", "-", "Rename (off)"]);
// No Get Info / Properties, no New Folder, no Show Desktop in this release.
for (const t of ["platinum", "memphis"]) {
    const all = JSON.stringify(icons.map((i) => M.iconMenu(t, icons, [i.id], i.id)).concat([M.desktopMenu(t, false)]));
    for (const banned of ["Info", "Properties", "New", "Show Desktop"]) assert.ok(all.indexOf(banned) < 0, t + ": " + banned);
}
same(labels(M.desktopMenu("platinum", false)), ["Clean Up", "-", "Always snap to grid"]);
same(labels(M.desktopMenu("platinum", true)), ["Clean Up", "-", "Always snap to grid ✓"]);
const arrange = M.desktopMenu("memphis", true);
same(labels(arrange), ["Arrange &Icons"]);
same(labels(arrange[0].submenu), ["by &Name", "by &Type", "by Si&ze", "by &Date", "-", "&Align to Grid ✓"]);
// Rows to messages.
const act = (row, ids, id, snap) => plain(M.menuAction(row, ids, id, snap, 7));
same(act({ action: "open" }, ["a", "b"], "a"), { send: { type: "open", ids: ["a", "b"] } });
same(act({ action: "trash" }, ["a"], "a"), { send: { type: "check-trash", request: 7, ids: ["a"] } });
same(act({ action: "empty-trash" }, ["trash"], "trash"), { send: { type: "check-empty-trash", request: 7 } });
same(act({ action: "eject" }, ["volume:sdb1"], "volume:sdb1"), { send: { type: "eject", id: "volume:sdb1" } });
same(act(M.desktopMenu("platinum", false)[0], [], ""), { send: { type: "arrange", by: "clean-up" } });
same(act(arrange[0].submenu[2], [], ""), { send: { type: "arrange", by: "size" } });
same(act(arrange[0].submenu[5], [], "", true), { send: { type: "set-snap", snap: false } });
same(act(M.desktopMenu("platinum", false)[2], [], "", false), { send: { type: "set-snap", snap: true } });
same(act({ action: "rename" }, ["a"], "a"), { local: "rename", id: "a" });
assert.equal(M.menuAction({ action: "open", disabled: true }, ["a"], "a"), null);
// Theme shapes.
same(plain(M.memphisItems(arrange)[0].submenu[5]), { text: "&Align to Grid", enabled: true, checked: true, row: plain(arrange[0].submenu[5]) });
assert.equal(M.platinumRows(M.desktopMenu("platinum", true))[2].check, true);
assert.equal(M.platinumRows(M.desktopMenu("platinum", true))[1].kind, "separator");

// ---- confirmations per theme
const trash1 = { type: "move-to-trash", count: 1 };
assert.equal(M.confirmPlan("platinum", trash1, ["file:notes.txt"], ["notes.txt"]), null, "Platinum moves to the Trash at once");
let p = M.confirmPlan("memphis", trash1, ["file:notes.txt"], ["notes.txt"]);
assert.equal(p.title, "Confirm File Delete");
assert.equal(p.text, "Are you sure you want to send 'notes.txt' to the Recycle Bin?");
same(plain(p.send), { type: "trash", ids: ["file:notes.txt"] });
p = M.confirmPlan("memphis", { type: "move-to-trash", count: 3 }, ["a", "b", "c"], ["a", "b", "c"]);
assert.equal(p.title, "Confirm Multiple File Delete");
assert.match(p.text, /these 3 items/);
for (const t of ["platinum", "memphis"]) {
    p = M.confirmPlan(t, { type: "permanent", count: 1, reason: "USB has no Trash." }, ["volume:x"], ["photo.jpg"]);
    assert.ok(p, t + " warns before a permanent delete");
    assert.equal(p.defaultButton, "cancel");
    assert.match(p.title + p.text, /USB has no Trash\./);
    assert.match(p.title + p.text, /undo/);
    same(plain(p.send), { type: "delete-permanently", ids: ["volume:x"] });
    p = M.confirmPlan(t, { type: "empty-trash", count: 3 }, ["trash"], ["Trash"]);
    assert.ok(p, t + " asks before Empty Trash");
    assert.equal(p.defaultButton, "cancel", t + ": Cancel / No is the default");
    assert.match(p.title + " " + p.text, /3 items/, "names the count");
    same(plain(p.send), { type: "empty-trash" });
}
assert.equal(M.confirmPlan("platinum", { type: "empty-trash", count: 3 }, [], []).cancel, "Cancel");
assert.equal(M.confirmPlan("memphis", { type: "empty-trash", count: 3 }, [], []).cancel, "&No");
assert.match(M.confirmPlan("platinum", { type: "empty-trash", count: 1 }, [], []).title, /1 item\./);
assert.equal(M.confirmPlan("memphis", { type: "who-knows" }, [], []), null);
// Errors are themed alerts with the provider's message.
const busy = { code: "busy", message: "The volume is in use by ghostty.", ids: ["volume:sdb1"] };
p = M.errorPlan("platinum", busy, ["USB"]);
assert.match(p.title, /“USB” could not be put away/);
assert.equal(p.text, "The volume is in use by ghostty.");
p = M.errorPlan("memphis", busy, ["USB"]);
assert.equal(p.title, "Eject");
assert.match(p.text, /'USB'/);
assert.match(p.text, /in use by ghostty/);
assert.equal(M.errorPlan("memphis", { code: "other", message: "x" }, []).text, "x");

// ---- the art
const needs = L.needs;
same(plain(M.artFor("platinum", icons[0], needs)), { type: "icon", name: "hensou-place-computer" });
same(plain(M.artFor("platinum", icons[2], needs)), { type: "icon", name: "hensou-place-trash-full" });
same(plain(M.artFor("memphis", emptyTrash[2], needs)), { type: "icon", name: "hensou-place-trash" });
same(plain(M.artFor("platinum", icons[1], needs)), { type: "icon", name: "hensou-place-network" });
same(plain(M.artFor("platinum", icons[3], needs)), { type: "icon", name: "hensou-kind-text" });
same(plain(M.artFor("platinum", icons[4], needs)), { type: "icon", name: "hensou-kind-folder" });
same(plain(M.artFor("platinum", icons[5], needs)), { type: "lettermark", letter: "K", tint: "#3a6ea5", label: "Krita" });
same(plain(M.artFor("platinum", icons[7], needs)), { type: "icon", name: "hensou-place-volume" });
const themed = (path) => Object.assign({}, icons[5], { art: { type: "themed", path } });
same(plain(M.artFor("platinum", themed("/run/current-system/sw/share/icons/Mountainous-platinum/32x32/apps/zed.png"), needs)),
    { type: "file", path: "/run/current-system/sw/share/icons/Mountainous-platinum/32x32/apps/zed.png" });
assert.equal(M.artFor("platinum", themed("/usr/share/icons/hicolor/48x48/apps/krita.png"), needs).type, "lettermark", "never hicolor");
assert.equal(M.artFor("platinum", themed("/usr/share/icons/Adwaita/48x48/apps/krita.png"), needs).type, "lettermark", "never Adwaita");
assert.equal(M.artFor("platinum", themed("/x/share/icons/Chicago95/apps/32/krita.png"), needs).type, "lettermark", "not the other theme's");
same(plain(M.artFor("memphis", Object.assign({}, icons[3], { art: { type: "generic", kind: "mystery" } }), needs)), { type: "icon", name: "hensou-kind-document" });
for (const k of M.GENERIC) assert.equal(M.artFor("memphis", Object.assign({}, icons[3], { art: { type: "generic", kind: k } }), needs).name, "hensou-kind-" + k);
assert.equal(M.aliasStyle("platinum", icons[6]), "italic");
assert.equal(M.aliasStyle("memphis", icons[6]), "arrow");
assert.equal(M.aliasStyle("memphis", icons[3]), "");

console.log("DESKTOP_ICONS_MODEL_TESTS_PASSED");
