.pragma library

// Prefer the smallest declared source that covers the physical slot. Unknown
// sizes (notably ICOs) beat a known undersized image, but not a known fit.
function choose(icons, pixels) {
    const candidates = (Array.isArray(icons) ? icons : []).filter(function (icon) {
        return icon && typeof icon.url === "string" && /^https?:\/\//i.test(icon.url);
    }).map(function (icon) {
        const sizes = (typeof icon.sizes === "string" ? icon.sizes : "").split(/\s+/).map(function (size) {
            if (size === "any") return Infinity;
            const m = /^(\d+)x(\d+)$/.exec(size);
            return m ? Math.min(Number(m[1]), Number(m[2])) : 0;
        }).filter(function (size) { return size > 0; });
        const fits = sizes.filter(function (size) { return size >= pixels; });
        return {url: icon.url, size: fits.length ? Math.min.apply(null, fits) : sizes.length ? Math.max.apply(null, sizes) : 0};
    });
    const fits = candidates.filter(function (icon) { return icon.size >= pixels; }).sort(function (a, b) { return a.size - b.size; });
    if (fits.length) return fits[0].url;
    const unknown = candidates.find(function (icon) { return icon.size === 0; });
    if (unknown) return unknown.url;
    candidates.sort(function (a, b) { return b.size - a.size; });
    return candidates.length ? candidates[0].url : "";
}

// ICO directory order is not a size order. Qt Image defaults to frame zero.
function frameFor(frames, pixels) {
    const fits = frames.filter(function (f) { return f.size >= pixels; }).sort(function (a, b) { return a.size - b.size; });
    const ordered = fits.length ? fits : frames.slice().sort(function (a, b) { return b.size - a.size; });
    return ordered.length ? ordered[0].frame : 0;
}

function smoothFor(nativePixels, pixels) { return nativePixels > pixels; }

function installed(appId, entryIcon) {
    return /^chrome-[a-p]{32}-Default$/.test(appId || "") && typeof entryIcon === "string" && entryIcon.charAt(0) === "/"
        ? "file://" + entryIcon : "";
}

function pageKey(page) { return [page.ws, page.url, page.favicon].join("\n"); }

// Read only decoration metadata. This never focuses, navigates or changes a
// page. Resolve manifest icons against the manifest URL, not the document.
function pageExpression() {
    return `(async function () {
        const icons = Array.from(document.querySelectorAll("link[rel]")).filter(function (link) {
            return /(^|\\s)(icon|apple-touch-icon|apple-touch-icon-precomposed)(\\s|$)/i.test(link.rel);
        }).slice(0, 64).map(function (link) { return {url: link.href, sizes: link.sizes.value}; });
        const manifest = document.querySelector('link[rel="manifest"]');
        if (manifest && /^https?:\\/\\//i.test(manifest.href)) {
            try {
                const response = await fetch(manifest.href, {signal: AbortSignal.timeout(1500)});
                if (response.ok) {
                    const data = await response.json();
                    if (Array.isArray(data.icons)) data.icons.slice(0, 64).forEach(function (icon) {
                        if (typeof icon.src === "string") icons.push({url: new URL(icon.src, response.url).href, sizes: typeof icon.sizes === "string" ? icon.sizes : ""});
                    });
                }
            } catch (e) { /* Declared link icons and CDP's favicon still work. */ }
        }
        return icons;
    })()`;
}
