// The tandem rule as a check (docs/plans/desktop-themes.md, "Tandem rule
// and parity ledger"): Platinum and Windows 98 move together. This fails
// when one theme's Desktop exposes something the other lacks, unless the
// ledger lists that gap with a reason.
//
// What a Desktop can expose is read from the code, not listed by hand:
//   - every method the shell calls on a Desktop (shell.qml: desktop.X(),
//     typeof desktop.X, fleetCall("X")), and every flag it reads
//     (anyDesktop("X"), desktops[i].X): an IPC-routed feature such as
//     cycle (Super+Tab) or toggleFleet (Super+B) is one of these;
//   - "omni-view": the Desktop claims the omni service's view (Super+P,
//     Ctrl+L), so the unthemed card stays hidden: it declares omniClaimed
//     and one of its theme's files calls claimView();
//   - "web.css": themes/<id>/web.css styles web pages;
//   - "picker": the registry's picker view exists and the Desktop loads it.
//
// The gaps are a fenced block in the ledger, one per line:
//   ```parity-gaps
//   <feature>  <theme id that lacks it>  <reason>
//   ```
// A gap that is no longer a gap fails too, so the ledger stays true when
// the missing piece lands.
//
//   node theme-parity.js <quickshell dir> <desktop-themes.md>
"use strict";
const fs = require("node:fs");
const path = require("node:path");

// The contract the shell uses, from shell.qml's own text.
function contract(shellQml) {
    const names = new Set();
    for (const m of shellQml.matchAll(/\bdesktop\.(\w+)\s*\(/g)) names.add(m[1]);
    for (const m of shellQml.matchAll(/typeof desktop\.(\w+)\s*===\s*"function"/g)) names.add(m[1]);
    for (const m of shellQml.matchAll(/fleetCall\("(\w+)"\)/g)) names.add(m[1]);
    const flags = new Set();
    for (const m of shellQml.matchAll(/anyDesktop\("(\w+)"\)/g)) flags.add(m[1]);
    for (const m of shellQml.matchAll(/desktops\[\d+\]\.(\w+)/g)) flags.add(m[1]);
    return { methods: [...names].sort(), flags: [...flags].sort() };
}

// What one theme has. t: { id, desktop (its QML text), files (every
// <prefix>*.qml text), webCss (bool), picker (bool: the file exists) }.
function features(t, c) {
    const has = new Set();
    for (const m of c.methods) if (new RegExp("\\bfunction\\s+" + m + "\\s*\\(").test(t.desktop)) has.add(m);
    for (const f of c.flags) if (new RegExp("\\bproperty\\s+\\w+\\s+" + f + "\\b").test(t.desktop)) has.add(f);
    if (/\bproperty\s+\w+\s+omniClaimed\b/.test(t.desktop) && t.files.some((s) => /\.claimView\s*\(/.test(s))) has.add("omni-view");
    if (t.webCss) has.add("web.css");
    if (t.picker && /\btheme\.picker\b/.test(t.desktop)) has.add("picker");
    return has;
}

// The ledger's gaps: [{ feature, theme, reason, line }].
function gaps(markdown) {
    const block = /```parity-gaps\n([\s\S]*?)```/.exec(markdown);
    if (!block) return null;
    const out = [];
    block[1].split("\n").forEach((raw, i) => {
        const line = raw.trim();
        if (line === "" || line.startsWith("#")) return;
        const m = /^(\S+)\s+(\S+)\s+(.*)$/.exec(line);
        out.push(m ? { feature: m[1], theme: m[2], reason: m[3].trim(), line: raw } : { feature: "", theme: "", reason: "", line: raw });
    });
    return out;
}

// The verdict. themes: as features(); shellQml; markdown: the ledger doc.
function parity(themes, shellQml, markdown) {
    const c = contract(shellQml);
    const errors = [];
    const has = {};
    for (const t of themes) has[t.id] = features(t, c);
    const all = new Set();
    for (const t of themes) for (const f of has[t.id]) all.add(f);
    const listed = gaps(markdown);
    if (listed === null) errors.push("the ledger has no ```parity-gaps block");
    const allowed = new Map();
    for (const g of listed || []) {
        if (!g.feature || !g.theme) { errors.push("unreadable gap line: " + g.line.trim()); continue; }
        if (!has[g.theme]) { errors.push(`gap for an unknown theme "${g.theme}": ${g.line.trim()}`); continue; }
        if (g.reason.length < 10) errors.push(`gap ${g.feature} in ${g.theme} needs a reason`);
        if (has[g.theme].has(g.feature)) errors.push(`${g.theme} now has ${g.feature}: remove the gap from the ledger and update its table`);
        else if (!all.has(g.feature)) errors.push(`no theme has ${g.feature} any more: remove the gap from the ledger`);
        allowed.set(g.feature + " " + g.theme, g);
    }
    const missing = [];
    for (const f of [...all].sort()) {
        for (const t of themes) {
            if (has[t.id].has(f)) continue;
            const others = themes.filter((o) => has[o.id].has(f)).map((o) => o.id);
            if (allowed.has(f + " " + t.id)) missing.push({ feature: f, theme: t.id, listed: true });
            else errors.push(`${t.id} lacks ${f}, which ${others.join(", ")} has: add it to ${t.id}, or list the gap with a reason in the ledger's parity-gaps block`);
        }
    }
    return { contract: c, has, missing, errors };
}

function main(dir, ledgerPath) {
    const registry = JSON.parse(fs.readFileSync(path.join(dir, "themes.json"), "utf8"));
    const files = fs.readdirSync(dir);
    const themes = registry.map((entry) => ({
        id: entry.id,
        desktop: fs.readFileSync(path.join(dir, entry.desktop), "utf8"),
        files: files.filter((f) => f.startsWith(entry.qmlPrefix) && f.endsWith(".qml")).map((f) => fs.readFileSync(path.join(dir, f), "utf8")),
        webCss: fs.existsSync(path.join(dir, "themes", entry.id, "web.css")),
        picker: !!entry.picker && fs.existsSync(path.join(dir, entry.picker))
    }));
    const r = parity(themes, fs.readFileSync(path.join(dir, "shell.qml"), "utf8"), fs.readFileSync(ledgerPath, "utf8"));
    const all = [...new Set(themes.flatMap((t) => [...r.has[t.id]]))].sort();
    console.log("feature".padEnd(18) + themes.map((t) => t.id.padEnd(10)).join(""));
    for (const f of all) {
        console.log(f.padEnd(18) + themes.map((t) => (r.has[t.id].has(f) ? "yes" : r.missing.some((m) => m.feature === f && m.theme === t.id) ? "gap" : "NO").padEnd(10)).join(""));
    }
    if (r.errors.length) {
        for (const e of r.errors) console.error("THEME_PARITY: " + e);
        console.error("THEME_PARITY_FAILED");
        process.exit(1);
    }
    console.log(`THEME_PARITY_PASSED features=${all.length} listed-gaps=${r.missing.length}`);
}

module.exports = { contract, features, gaps, parity };
if (require.main === module) main(process.argv[2] || __dirname + "/..", process.argv[3]);
