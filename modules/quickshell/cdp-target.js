.pragma library

function hostOf(url) {
    const match = /^[a-z]+:\/\/([^\/]+)/.exec(url || "");
    return match ? match[1] : "";
}

// Match only browser app windows. Host wins; a title tie must have exactly
// one target whose URL history contains the app-id host. Otherwise refuse
// to navigate rather than selecting another window by list order.
function targetFor(pages, history, appId, title) {
    const match = /^chrome-(.+?)__-/.exec(appId || "");
    if (!match) return null;
    const host = match[1];
    const byHost = pages.filter(function (page) { return page.host === host; });
    if (byHost.length === 1) return byHost[0];
    const candidates = (byHost.length ? byHost : pages).filter(function (page) {
        return title !== "" && page.title === title;
    });
    if (candidates.length === 1) return candidates[0];
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
