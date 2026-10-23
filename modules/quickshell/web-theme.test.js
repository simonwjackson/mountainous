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
        // A well (field, check box) stays findable on a white or a near-black page.
        for (const page of ["#ffffff", "#121212"]) {
            for (const fill of ["--mtn-field", "--mtn-face-down"]) {
                assert.ok(Math.max(contrast(hex("--mtn-well-edge"), page), contrast(hex(fill), page)) >= 3,
                    `${theme.id}/${mode}: ${fill} on ${page}`);
            }
        }
        for (const page of ["#ffffff", "#000000", hex("--mtn-field")]) {
            if (page === "#000000" && mode === "light") continue;
            assert.ok(contrast(hex("--mtn-focus"), page) >= 3, `${theme.id}/${mode}: focus on ${page}`);
        }
    }
}
assert.ok(linted >= 1, "at least one theme ships web.css");
console.log(`WEB_THEME_TESTS_PASSED themes=${linted}`);
