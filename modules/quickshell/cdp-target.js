.pragma library

function hostOf(url) {
    const match = /^[a-z]+:\/\/([^\/]+)/.exec(url || "");
    return match ? match[1] : "";
}

function isBrowser(appId) {
    return /^(chromium|chromium-browser)$/i.test(appId || "") || /^chrome-/.test(appId || "");
}

// CDP's HTTP target list HTML-escapes titles; native window titles are
// already decoded. One pass preserves a page's literal entity text.
function decodeTitle(title) {
    const named = {amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: "\u00a0"};
    return String(title || "").replace(/&(?:(amp|lt|gt|quot|apos|nbsp)|#([0-9]+)|#[xX]([0-9a-fA-F]+));/g,
        function (entity, name, decimal, hex) {
            if (name) return named[name];
            const point = parseInt(decimal || hex, decimal ? 10 : 16);
            // Leave invalid scalar values unchanged rather than inventing a match.
            if (point <= 0 || point > 0x10ffff || (point >= 0xd800 && point <= 0xdfff)) return entity;
            return String.fromCodePoint(point);
        });
}

// Share endpoint/host/title selection between navigation and favicon probes.
// Returning all ties lets the caller gather evidence, never pick list order.
function candidatesFor(pages, appId, title) {
    const match = /^chrome-(.+?)__-/.exec(appId || "");
    if (!match) {
        if (!/^(chromium|chromium-browser)$/i.test(appId || "") && !/^chrome-[a-p]{32}-/.test(appId || "")) return [];
        const plain = String(title || "").replace(/ - Chromium$/, "");
        const candidates = pages.filter(function (page) {
            return (!page.endpoint || page.endpoint === "normal") && plain !== "" && decodeTitle(page.title) === plain;
        });
        return candidates;
    }
    const host = match[1];
    // URL-named app classes are the declared web-app root. Adding normal
    // Chromium's endpoint must not make its same-host page win this match.
    const appPages = pages.filter(function (page) { return !page.endpoint || page.endpoint === "web"; });
    const byHost = appPages.filter(function (page) { return page.host === host; });
    if (byHost.length === 1) return byHost;
    const candidates = (byHost.length ? byHost : appPages).filter(function (page) {
        return title !== "" && decodeTitle(page.title) === title;
    });
    return candidates;
}

// Navigation may also use a unique original host from observed URL history.
// Focus evidence is only icon metadata, not authority to navigate a window.
function targetFor(pages, history, appId, title) {
    const candidates = candidatesFor(pages, appId, title);
    if (candidates.length === 1) return candidates[0];
    const match = /^chrome-(.+?)__-/.exec(appId || "");
    if (!match) return null;
    const host = match[1];
    const byHistory = candidates.filter(function (page) {
        return (history[page.id] || []).some(function (url) { return hostOf(url) === host; });
    });
    return byHistory.length === 1 ? byHistory[0] : null;
}

// Keep observed and requested URLs for live targets only. This is volatile
// navigation evidence, not another persistent browser history.
function remember(history, pages) {
    const next = {};
    for (const page of pages) {
        const urls = (history[page.id] || []).slice();
        if (page.url && urls.indexOf(page.url) < 0) urls.push(page.url);
        next[page.id] = urls;
    }
    return next;
}

// Native toplevels and shell window rows share address/title; rows expose
// appId directly, native toplevels expose it through wayland.
function appIdOf(window) {
    return window ? (window.wayland ? window.wayland.appId : window.appId) || "" : "";
}

function windowKey(address) { return String(address || "").replace(/^0x/, ""); }

// Focus evidence is used only after the ordinary unique host/title match.
// Page identity survives navigation; titles and URLs need not stay equal.
function faviconFor(window, pages, focusMap) {
    const appId = appIdOf(window);
    if (!window || !isBrowser(appId)) return "";
    const candidates = candidatesFor(pages, appId, window.title || "");
    const id = focusMap[windowKey(window.address)];
    const page = candidates.length === 1 ? candidates[0]
        : id ? pages.find(function (p) { return p.id === id; }) : null;
    const url = page ? page.favicon || "" : "";
    return /^https?:\/\//i.test(url) ? url : "";
}

// Zero or several focused pages are not evidence. Never pick array order.
function recordFocus(focusMap, address, focusedIds) {
    const key = windowKey(address);
    if (!key || focusedIds.length !== 1 || typeof focusedIds[0] !== "string" || focusedIds[0] === "") return focusMap;
    const next = Object.assign({}, focusMap);
    next[key] = focusedIds[0];
    return next;
}

function pruneFocusMap(focusMap, windows, pages) {
    const addresses = windows.map(function (w) { return windowKey(w.address); });
    const ids = pages.map(function (p) { return p.id; });
    const next = {};
    for (const address of Object.keys(focusMap)) {
        if (addresses.indexOf(address) >= 0 && ids.indexOf(focusMap[address]) >= 0)
            next[address] = focusMap[address];
    }
    return next;
}
