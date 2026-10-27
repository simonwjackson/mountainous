// The theme-to-stylesheet policy, the in-page script and a lint of each
// theme's web.css, under node with no browser.
//   node web-theme.test.js web-theme.js web-theme-page.js <quickshell dir>
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const policyPath = process.argv[2] || path.join(__dirname, "web-theme.js");
const pagePath = process.argv[3] || path.join(__dirname, "web-theme-page.js");
const root = process.argv[4] || __dirname;
const policy = {};
vm.runInNewContext(fs.readFileSync(policyPath, "utf8").replace(/^\.pragma library\s*$/m, ""), policy);
const pageText = fs.readFileSync(pagePath, "utf8");
const registry = JSON.parse(fs.readFileSync(path.join(root, "themes.json"), "utf8"));

// ---- policy -------------------------------------------------------------
assert.equal(policy.cssPath("platinum"), "themes/platinum/web.css");
assert.equal(policy.cssPath("win98"), "themes/win98/web.css");
for (const bad of ["", "../x", "Platinum", "a/b", null, undefined]) assert.equal(policy.cssPath(bad), "");

const fixture = [
    "/* header */",
    "/* @tokens all */ :root{--mtn-hair:1px}",
    "/* @tokens light */ :root{--mtn-text:#000}",
    "/* @tokens dark */ :root{--mtn-text:#eee}",
    "/* @level type */ h1{a:b}",
    "/* @level scrollbars */ ::-webkit-scrollbar{c:d}",
    "/* @level forms */ button{e:f}",
].join("\n");
const light = policy.payload(fixture, "platinum", "light", false);
assert.equal(light.appearance, "light");
assert.match(light.tokens, /--mtn-hair:1px[\s\S]*--mtn-text:#000/);
assert.doesNotMatch(light.tokens, /#eee/);
assert.deepEqual(JSON.parse(JSON.stringify(light.order)), ["type", "scrollbars", "forms"]);
assert.equal(light.levels.forms, "button{e:f}");
assert.doesNotMatch(light.levels.type, /header/);
assert.equal(policy.payload(fixture, "platinum", "dark", false).appearance, "dark");
// Extra dark blackens only the bar: page controls use dark ...
assert.equal(policy.payload(fixture, "platinum", "dark", true).appearance, "dark");
// ... and Extra dark means nothing in light mode.
assert.equal(policy.payload(fixture, "platinum", "light", true).appearance, "light");
// A theme may ship its own extra block.
const extra = policy.payload(fixture + "\n/* @tokens extra */ :root{--mtn-text:#fff}", "x", "dark", true);
assert.equal(extra.appearance, "extra");
assert.match(extra.tokens, /#fff/);
// A missing file, or one without tokens for the mode, restyles nothing.
for (const css of ["", "/* @level forms */ button{}", "/* @tokens light */ :root{}"]) {
    const off = policy.payload(css, "win98", "dark", false);
    assert.equal(off.appearance, "");
    assert.equal(off.tokens, "");
    for (const level of off.order) assert.equal(off.levels[level], "");
}
const src = policy.script(pageText, light);
assert.ok(src.startsWith("(") && src.includes("(function (payload)") && src.endsWith(");"), "script wraps the page function");
assert.doesNotThrow(() => new vm.Script(src), "the wrapped source parses");
for (const [host, rule] of Object.entries(policy.sites)) {
    assert.match(host, /^[a-z0-9.-]+$/, host);
    assert.ok(typeof rule.why === "string" && rule.why.length > 10, host + ": record what broke");
    for (const level of rule.off || []) assert.ok(policy.levels.includes(level), host + ": " + level);
}

// ---- the in-page script, in a fake window ------------------------------
class FakeSheet {
    constructor() { this.text = ""; }
    replaceSync(text) { this.text = text; }
}
function frame(hostname, ancestors) {
    const listeners = {};
    const document = {
        adoptedStyleSheets: [],
        addEventListener(type, fn) { listeners[type] = fn; },
    };
    const window = { addEventListener(type, fn) { listeners["w:" + type] = fn; } };
    const context = {
        window, document, CSSStyleSheet: FakeSheet, Symbol, Object, Date, URL,
        location: { hostname, ancestorOrigins: ancestors || [] },
    };
    window.document = document;
    vm.createContext(context);
    return { context, listeners, run: (data) => vm.runInContext(policy.script(pageText, data), context),
        state: () => vm.runInContext("window[Symbol.for('mountainous.webTheme')]", context) };
}
const sample = (overrides) => Object.assign({ v: 1, theme: "platinum", appearance: "light", tokens: "T",
    levels: { type: "TY", scrollbars: "SB", forms: ":where(button):where(:not([data-mtn-skip])){x:y}" },
    order: ["type", "scrollbars", "forms"], sites: {} }, overrides || {});

let f = frame("en.wikipedia.org");
const own = new FakeSheet();
f.context.document.adoptedStyleSheets = [own];
f.run(sample());
let sheets = f.context.document.adoptedStyleSheets;
assert.equal(sheets.length, 5, "the page's sheet plus tokens and three levels");
assert.equal(sheets[0], own, "the page's own sheets stay first");
assert.deepEqual(sheets.slice(1).map((s) => s.text), ["T", "TY", "SB", ":where(button):where(:not([data-mtn-skip])){x:y}"]);
// A live change replaces text in the same sheets; nothing is added.
f.run(sample({ appearance: "dark", tokens: "D" }));
assert.equal(f.context.document.adoptedStyleSheets.length, 5);
assert.equal(f.context.document.adoptedStyleSheets[1].text, "D");
assert.equal(f.state().appearance, "dark");
// A page that replaces adoptedStyleSheets gets ours back once it settles.
f.context.document.adoptedStyleSheets = [own];
f.listeners.DOMContentLoaded();
assert.equal(f.context.document.adoptedStyleSheets.length, 5);
// A theme without web.css empties every sheet.
f.run(policy.payload("", "win98", "light", false));
assert.ok(f.context.document.adoptedStyleSheets.slice(1).every((s) => s.text === ""));

// Site rules match the host and each parent domain.
const sites = { "youtube.com": { off: ["forms"], why: "fixture" }, "github.com": { skip: ".btn-octicon", why: "fixture" } };
f = frame("music.youtube.com");
f.run(sample({ sites }));
assert.deepEqual(f.context.document.adoptedStyleSheets.map((s) => s.text), ["T", "TY", "SB", ""]);
assert.deepEqual([...f.state().off], ["forms"]);
f = frame("github.com");
f.run(sample({ sites }));
assert.match(f.context.document.adoptedStyleSheets[3].text, /:not\(\[data-mtn-skip\], \.btn-octicon\)/);
f = frame("notyoutube.com");
f.run(sample({ sites }));
assert.notEqual(f.context.document.adoptedStyleSheets[3].text, "");
// about:blank and srcdoc frames take the embedding page's host.
f = frame("", ["https://music.youtube.com"]);
f.run(sample({ sites }));
assert.equal(f.state().host, "music.youtube.com");
assert.equal(f.context.document.adoptedStyleSheets[3].text, "");
// A document that cannot adopt sheets is left alone.
const bare = vm.createContext({ window: {}, document: {}, CSSStyleSheet: FakeSheet, Symbol, Object, location: { hostname: "x" } });
vm.runInContext(policy.script(pageText, sample()), bare);
assert.equal(vm.runInContext("window[Symbol.for('mountainous.webTheme')]", bare), undefined);
assert.doesNotMatch(pageText, /createElement|innerHTML|insertAdjacent|appendChild|setAttribute/, "no DOM edits, no <style>");

// ---- lint every theme's web.css ----------------------------------------
function stripComments(css) { return css.replace(/\/\*[\s\S]*?\*\//g, ""); }
function topLevelRules(css) {
    // Selector preludes of style rules, at any @media depth.
    const out = [];
    let depth = 0, start = 0, stack = [];
    for (let i = 0; i < css.length; i++) {
        if (css[i] === "{") {
            const prelude = css.slice(start, i).trim();
            stack.push(prelude.startsWith("@") ? "at" : "rule");
            if (!prelude.startsWith("@")) out.push(prelude);
            depth++; start = i + 1;
        } else if (css[i] === "}") {
            depth--; stack.pop(); start = i + 1;
            assert.ok(depth >= 0, "unbalanced }");
        } else if (css[i] === ";" && stack[stack.length - 1] !== "rule") start = i + 1;
    }
    assert.equal(depth, 0, "unbalanced {");
    return out;
}
function splitTop(list) {
    const parts = []; let depth = 0, cur = "";
    for (const ch of list) {
        if (ch === "(") depth++;
        if (ch === ")") depth--;
        if (ch === "," && depth === 0) { parts.push(cur.trim()); cur = ""; } else cur += ch;
    }
    parts.push(cur.trim());
    return parts;
}
function luminance(hex) {
    const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
        .map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}
function contrast(a, b) {
    const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p);
    return (x + 0.05) / (y + 0.05);
}
function tokens(block) {
    const out = {};
    for (const m of block.matchAll(/(--mtn-[a-z0-9-]+)\s*:\s*([^;]+);/g)) out[m[1]] = m[2].trim();
    return out;
}

let linted = 0;
for (const theme of registry) {
    const file = path.join(root, policy.cssPath(theme.id));
    if (!fs.existsSync(file)) continue;
    linted++;
    const css = fs.readFileSync(file, "utf8");
    const sections = policy.parse(css);
    for (const level of policy.levels) assert.ok(sections.levels[level], `${theme.id}: level ${level}`);
    for (const a of theme.appearances) assert.ok(sections.tokens[a.mode], `${theme.id}: tokens ${a.mode}`);
    assert.doesNotMatch(stripComments(css), /url\(/, `${theme.id}: no url(), a strict img-src would block it`);
    assert.doesNotMatch(stripComments(css), /@import/, `${theme.id}: replaceSync rejects @import`);
    // `X :where(:not(...))` with a space is a descendant selector, not a guard.
    assert.doesNotMatch(stripComments(css), /\)\s+:where\(:not\(/, `${theme.id}: a guard must touch the selector it guards`);
    assert.doesNotMatch(stripComments(css), /@layer/, `${theme.id}: a layered !important would beat the site's own !important`);
    // The reset that keeps ::-webkit-scrollbar alive.
    assert.match(sections.levels.scrollbars, /:where\(\*\)\s*\{\s*scrollbar-color:\s*auto !important;\s*scrollbar-width:\s*auto !important;/);
    // Token blocks define the same names, and every name used is defined.
    const all = tokens(sections.tokens.all);
    const modes = theme.appearances.map((a) => a.mode);
    const names = Object.keys(tokens(sections.tokens[modes[0]])).sort();
    for (const mode of modes) assert.deepEqual(Object.keys(tokens(sections.tokens[mode])).sort(), names, `${theme.id}: ${mode} tokens`);
    for (const m of css.matchAll(/var\((--mtn-[a-z0-9-]+)\)/g)) {
        assert.ok(m[1] in all || names.includes(m[1]), `${theme.id}: ${m[1]} is not defined`);
    }
    // Low specificity: every selector in a level starts with :where(),
    // :root, or a bare pseudo-element.
    for (const level of policy.levels) {
        for (const prelude of topLevelRules(stripComments(sections.levels[level]))) {
            for (const selector of splitTop(prelude)) {
                assert.match(selector, /^(:where\(|:root$|::[a-z-]+)/, `${theme.id}/${level}: ${selector}`);
            }
        }
    }
    // Words on controls stay readable in each mode; focus rings stay visible.
    for (const mode of modes) {
        const t = Object.assign({}, tokens(sections.tokens[mode]));
        const hex = (name) => { assert.match(t[name], /^#[0-9a-f]{6}$/i, `${theme.id}/${mode}: ${name}`); return t[name]; };
        assert.ok(contrast(hex("--mtn-text"), hex("--mtn-face")) >= 4.5, `${theme.id}/${mode}: text on face`);
        assert.ok(contrast(hex("--mtn-text"), hex("--mtn-field")) >= 4.5, `${theme.id}/${mode}: text on field`);
        assert.ok(contrast(hex("--mtn-text"), hex("--mtn-face-down")) >= 4.5, `${theme.id}/${mode}: text on pressed face`);
        assert.ok(contrast(hex("--mtn-selection-text"), hex("--mtn-selection")) >= 4.5, `${theme.id}/${mode}: selection`);
        assert.ok(contrast(hex("--mtn-text"), hex("--mtn-thumb")) >= 3, `${theme.id}/${mode}: grip and arrows`);
        // A well (field, check box) stays findable on a white or a near-black
        // page: its fill or one of its outer edges stands out. A theme whose
        // well has a second outer colour (Win98: dark top left, light bottom
        // right) names it --mtn-well-edge-low.
        const edges = ["--mtn-well-edge"].concat(t["--mtn-well-edge-low"] ? ["--mtn-well-edge-low"] : []);
        for (const page of ["#ffffff", "#121212"]) {
            for (const fill of ["--mtn-field", "--mtn-face-down"]) {
                assert.ok(Math.max(contrast(hex(fill), page), ...edges.map((n) => contrast(hex(n), page))) >= 3,
                    `${theme.id}/${mode}: ${fill} on ${page}`);
            }
        }
        for (const page of ["#ffffff", "#000000", hex("--mtn-field")]) {
            if (page === "#000000" && mode === "light") continue;
            assert.ok(contrast(hex("--mtn-focus"), page) >= 3, `${theme.id}/${mode}: focus on ${page}`);
        }
    }
}
assert.ok(linted >= 2, "Platinum and Win98 ship web.css");

// ---- Win98: the same sections and guards as Platinum's, its own rules ---
// Style rules with their bodies, at any @media depth.
function styleRules(css) {
    const out = [];
    let start = 0;
    const stack = [];
    for (let i = 0; i < css.length; i++) {
        if (css[i] === "{") {
            const prelude = css.slice(start, i).trim();
            stack.push({ prelude, at: prelude.startsWith("@"), open: i + 1 });
            start = i + 1;
        } else if (css[i] === "}") {
            const r = stack.pop();
            if (r && !r.at) out.push({ prelude: r.prelude, body: css.slice(r.open, i) });
            start = i + 1;
        }
    }
    return out;
}
// The guard lists: the inside of every :where(:not(...)).
function guards(css) {
    const out = [];
    const open = ":where(:not(";
    for (let i = css.indexOf(open); i >= 0; i = css.indexOf(open, i + 1)) {
        let depth = 2, j = i + open.length;
        for (; j < css.length && depth > 0; j++) { if (css[j] === "(") depth++; if (css[j] === ")") depth--; }
        out.push(css.slice(i + open.length, j - 2).replace(/\s+/g, " ").trim());
    }
    return out;
}
const strip = (sections) => ({ tokens: Object.fromEntries(Object.entries(sections.tokens).map(([k, v]) => [k, stripComments(v)])),
    levels: Object.fromEntries(Object.entries(sections.levels).map(([k, v]) => [k, stripComments(v)])) });
const win98Raw = fs.readFileSync(path.join(root, "themes/win98/web.css"), "utf8");
const win98Css = stripComments(win98Raw);
const win98 = strip(policy.parse(win98Raw));
const plat = strip(policy.parse(fs.readFileSync(path.join(root, "themes/platinum/web.css"), "utf8")));
assert.deepEqual(Object.keys(win98.levels).sort(), Object.keys(plat.levels).sort(), "win98: Platinum's levels");
assert.deepEqual(Object.keys(win98.tokens).sort(), Object.keys(plat.tokens).filter((k) => k !== "extra").sort(), "win98: Platinum's token blocks");
// Every Platinum guard is kept, once for each place Platinum uses it: a
// Win98 guard of its own in the same level skips at least what it skips
// (Win98 may skip more: W95FA stays off ARIA tabs and switches, which its
// forms level leaves alone too).
for (const level of policy.levels) {
    const ours = guards(win98.levels[level]).map((g) => new Set(splitTop(g)));
    const missing = guards(plat.levels[level]).filter((g) => {
        const i = ours.findIndex((w) => splitTop(g).every((t) => w.has(t)));
        if (i >= 0) ours.splice(i, 1);
        return i < 0;
    });
    assert.deepEqual(missing, [], `win98/${level}: every Platinum guard is kept`);
}
// One Win98 pixel is 2 device px at every resolution it names.
const length = (v) => {
    const m = /^calc\((\d+(?:\.\d+)?)px \/ (\d+(?:\.\d+)?)\)$/.exec(v) || /^(\d+(?:\.\d+)?)px$/.exec(v);
    assert.ok(m, "a length: " + v);
    return m[2] ? Number(m[1]) / Number(m[2]) : Number(m[1]);
};
// The base block (before the @media blocks): 1 px is 2 device px at 2 dppx.
const base = tokens(/^:root \{[^}]*\}/.exec(win98.tokens.all)[0]);
assert.equal(length(base["--mtn-u"]), 1, "1 px at 2 dppx");
const resolutions = [...win98.tokens.all.matchAll(/@media \(resolution: ([\d.]+)dppx\) \{ :root \{ --mtn-u: ([^;]+); \} \}/g)];
assert.ok(resolutions.length >= 6, "win98: u at 1, 1.25, 1.5, 1.75, 2.5 and 3 dppx");
for (const [, dppx, u] of resolutions) assert.ok(Math.abs(length(u) * Number(dppx) - 2) < 1e-9, `win98: u = 2 device px at ${dppx} dppx`);
// W95FA at its one size, 12.5 u, and on buttons, drop-down lists and legends only.
assert.equal(base["--mtn-ui-size"], "calc(12.5 * var(--mtn-u))");
assert.match(base["--mtn-ui-font"], /^"W95FA Grid",/);
const faced = styleRules(win98Css).filter((r) => /font-family/.test(r.body));
assert.ok(faced.length >= 1, "win98: W95FA is set somewhere");
for (const r of faced) {
    assert.match(r.body, /font-family: var\(--mtn-ui-font\) !important;/, "win98: only W95FA: " + r.prelude);
    assert.match(r.body, /font-size: var\(--mtn-ui-size\) !important;/, "win98: W95FA at 12.5 u: " + r.prelude);
    for (const sel of splitTop(r.prelude)) {
        const elements = /^:where\(([^)]*?)(?:\)|, input)/.exec(sel);
        assert.ok(elements, "win98: " + sel);
        for (const el of splitTop(sel.slice(":where(".length, sel.indexOf("):where(")))) {
            assert.match(el, /^(button|legend|select:not\(\[multiple\]\):is\(:not\(\[size\]\), \[size="1"\]\)|input:is\(\[type="button" i\], \[type="submit" i\], \[type="reset" i\]\))$/,
                "win98: W95FA only on buttons, drop-down lists and legends, not " + el);
        }
    }
}
assert.doesNotMatch(win98Css, /:where\(html|body\b/, "win98: body text keeps the site's font");
assert.doesNotMatch(win98Css, /font-size:(?! var\(--mtn-ui-size\))/, "win98: no other font size");
// Scroll bars are 16 u.
assert.equal(base["--mtn-bar"], "calc(16 * var(--mtn-u))");
assert.match(win98.levels.scrollbars, /::-webkit-scrollbar \{ width: var\(--mtn-bar\); height: var\(--mtn-bar\);/);
// The colours are Win98Tokens.qml's, both schemes.
const qmlTokens = fs.readFileSync(path.join(root, "Win98Tokens.qml"), "utf8");
const palette = (dark) => {
    const out = {};
    for (const m of qmlTokens.matchAll(/^\s*(\w+): (?:dark \? "(#[0-9a-f]{6})" : "(#[0-9a-f]{6})"|"(#[0-9a-f]{6})"),?$/gm)) out[m[1]] = m[4] || (dark ? m[2] : m[3]);
    return out;
};
const same = { "--mtn-face": "face", "--mtn-light": "hi", "--mtn-light-inner": "li", "--mtn-shadow": "sh", "--mtn-dark": "dk",
    "--mtn-text": "text", "--mtn-text-off": "gray", "--mtn-field": "win", "--mtn-field-text": "winText",
    "--mtn-selection": "selection", "--mtn-selection-text": "selectionText", "--mtn-dither": "dither" };
for (const mode of ["light", "dark"]) {
    const css = tokens(win98.tokens[mode]), qml = palette(mode === "dark");
    for (const [name, key] of Object.entries(same)) assert.equal(css[name].toLowerCase(), qml[key], `win98/${mode}: ${name} is Win98Tokens.${key}`);
}
console.log(`WEB_THEME_TESTS_PASSED themes=${linted}`);
