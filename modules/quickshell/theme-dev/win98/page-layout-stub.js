// DEV HARNESS (not delivered): a stand-in for `mountainous-page-layout`
// (Contract 2 in docs/plans/page-layout-control.md) for the Win98 harness
// session. It applies each call to $XDG_RUNTIME_DIR/mountainous-page-layout.json
// (Contract 1), written atomically, so the window sees its own changes as
// it would from page-layout.lua. It logs every call to commands.log beside
// the runtime directory and exits 2 on a bad argument.
//
//   node page-layout-stub.js <command> [args ...]
"use strict";
const fs = require("node:fs");
const path = require("node:path");

const run = process.env.XDG_RUNTIME_DIR;
const file = path.join(run, "mountainous-page-layout.json");
fs.appendFileSync(path.join(run, "..", "commands.log"), "mountainous-page-layout " + process.argv.slice(2).join(" ") + "\n");

const bad = (why) => { process.stderr.write("mountainous-page-layout: " + why + "\n"); process.exit(2); };
let state;
try { state = JSON.parse(fs.readFileSync(file, "utf8")); } catch (e) { bad("no state file"); }
const FIELDS = ["cap", "floating", "gap"];
const clampGap = (v) => Math.max(0, Math.min(48, Math.round(Number(v) / 4) * 4));
const defOf = (monitor) => state.defaults[monitor] || state.fallback;
const own = (p) => { const d = defOf(p.monitor); p.own = FIELDS.some((k) => p[k] !== d[k]); };
const pageOf = (id) => {
    // "active": the harness's page is the lowest page on the first screen
    // the file names; good enough for the harness, which shows one screen.
    const key = id === "active" ? Object.keys(state.pages).sort((a, b) => a - b)[0] : id;
    const p = state.pages[key];
    if (!p) bad("no page " + id);
    return p;
};
const assign = (target, pairs) => {
    for (const kv of pairs) {
        const m = /^(cap|floating|gap|zen)=(.*)$/.exec(kv);
        if (!m) bad("bad setting " + kv);
        const [, k, v] = m;
        if (k === "cap") { const n = Number(v); if (![1, 2, 3].includes(n)) bad("cap 1..3"); target.cap = n; }
        else if (k === "gap") { if (!isFinite(Number(v))) bad("gap 0..48"); target.gap = clampGap(v); }
        else { if (v !== "true" && v !== "false") bad(k + " true|false"); target[k] = v === "true"; }
    }
};

const [cmd, ...args] = process.argv.slice(2);
if (cmd === "page") {
    const p = pageOf(args[0]);
    assign(p, args.slice(1));
    own(p);
} else if (cmd === "page-default") {
    const p = pageOf(args[0]);
    const d = defOf(p.monitor);
    const which = args[1] === "all" ? FIELDS : [args[1]];
    if (!which.every((k) => FIELDS.includes(k))) bad("field cap|floating|gap|all");
    for (const k of which) p[k] = d[k];
    own(p);
} else if (cmd === "default") {
    const name = args[0];
    if (!name) bad("no connector");
    state.defaults[name] = Object.assign({}, defOf(name));
    if (args.slice(1).some((kv) => kv.startsWith("zen="))) bad("a default has no zen");
    assign(state.defaults[name], args.slice(1));
    for (const id in state.pages) if (state.pages[id].monitor === name) own(state.pages[id]);
} else if (cmd === "reset") {
    const d = defOf(args[0]);
    for (const id in state.pages) {
        const p = state.pages[id];
        if (p.monitor !== args[0]) continue;
        for (const k of FIELDS) p[k] = d[k];
        p.zen = false;
        p.own = false;
    }
} else if (cmd === "step-gap") {
    const p = pageOf(args[0]);
    p.gap = clampGap(p.gap + Number(args[1] || 0));
    own(p);
} else if (cmd === "toggle-floating") {
    const p = pageOf(args[0]);
    p.floating = !p.floating;
    own(p);
} else {
    bad("unknown command " + cmd);
}
const tmp = file + ".tmp";
fs.writeFileSync(tmp, JSON.stringify(state) + "\n");
fs.renameSync(tmp, file);
