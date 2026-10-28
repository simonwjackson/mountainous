.pragma library
// The desktop pattern: which tile a theme draws in each appearance, and
// how big a tile cell is on a screen. Pure, so desktop-art.test.js and
// checks.native-themes (after each desktop-theme change) run it too.
//
// A theme's "art" entry in themes.json names one tile per appearance:
// "light", "dark" and, when the theme honours Extra dark, "extra". A tile
// is an 8 x 8 SVG; "patternCell" is device pixels per tile pixel at scale
// 1.5 (Platinum 3, one 72-dpi Mac pixel; Win98 2, one Win98 unit).

// "light", "dark" or "extra": desktop-theme's own rule (theme.nix).
function appearance(entry, mode, extraDark) {
    const dark = mode !== "light";
    if (dark && extraDark === true && entry && entry.options && entry.options.extraDark === true)
        return "extra";
    return dark ? "dark" : "light";
}

// The tile's path under the shell directory, or "" for none (the
// compositor's black then shows).
function pattern(entry, mode, extraDark) {
    if (!entry || !entry.art || !entry.art.patterns) return "";
    return entry.art.patterns[appearance(entry, mode, extraDark)] || "";
}

// Device pixels per tile pixel on a screen of this device pixel ratio,
// and the tile's logical size. Qt takes the tile's size in whole logical
// pixels, so the cell grows to the first size whose 8-cell tile is whole
// in logical pixels (at 1.5: Platinum 3 -> 16 logical; Win98 2 -> 3, its
// tiles are plain). Then every tile pixel lands on whole device pixels.
function tile(base, dpr) {
    const ratio = dpr > 0 ? dpr : 1;
    const start = Math.max(1, Math.round((base > 0 ? base : 1) * ratio / 1.5));
    for (let cell = start; cell <= start * 8; cell++) {
        const logical = 8 * cell / ratio;
        if (Math.abs(logical - Math.round(logical)) < 1e-6)
            return { cell: cell, logical: Math.round(logical) };
    }
    return { cell: start, logical: Math.max(1, Math.round(8 * start / ratio)) };
}
