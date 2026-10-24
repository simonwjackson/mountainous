.pragma library

// The glance space's widgets and their saved state. Theme-neutral: a theme
// maps each id to its own view. Order is priority: Clean Up places the
// widgets in this order, Fleet first. Add a widget here and give it a view;
// nothing else changes.
var WIDGETS = [
    {id: "fleet", label: "Fleet"},
    {id: "disks", label: "Disks"}
];

function ids() { return WIDGETS.map(function (w) { return w.id; }); }

function known(id) { return ids().indexOf(id) >= 0; }

function label(id) {
    for (const w of WIDGETS) if (w.id === id) return w.label;
    return "";
}

function finite(v) { return typeof v === "number" && Number.isFinite(v); }

// The saved state, from $XDG_STATE_HOME/mountainous/glance.json. Anything
// unknown, malformed or out of range falls back to the default, so a bad
// file can never hide a widget for good.
//   enabled  {id: bool}           every widget on by default
//   places   {id: {r, t}}         remembered places until Clean Up
//   shaded   {id: bool}           WindowShade in the glance space
//   fleet    {r, t, w, h, shaded} the standalone Fleet window
function parse(text) {
    let data = {};
    try { data = JSON.parse(text || "{}") || {}; } catch (e) { data = {}; }
    if (typeof data !== "object" || Array.isArray(data)) data = {};
    const state = {enabled: {}, places: {}, shaded: {}, fleet: {}};
    for (const id of ids()) {
        const on = data.enabled && data.enabled[id];
        state.enabled[id] = typeof on === "boolean" ? on : true;
        const p = data.places && data.places[id];
        if (p && finite(p.r) && finite(p.t)) state.places[id] = {r: Math.round(p.r), t: Math.round(p.t)};
        state.shaded[id] = !!(data.shaded && data.shaded[id] === true);
    }
    const f = data.fleet && typeof data.fleet === "object" ? data.fleet : {};
    for (const key of ["r", "t", "w", "h"]) if (finite(f[key]) && f[key] >= 0) state.fleet[key] = Math.round(f[key]);
    state.fleet.shaded = f.shaded === true;
    return state;
}

function serialize(state) {
    return JSON.stringify(parse(JSON.stringify(state || {})), null, 1) + "\n";
}

// Enabled widgets in priority order.
function enabledIds(enabled) {
    return ids().filter(function (id) { return !enabled || enabled[id] !== false; });
}

// A new state with one change; the input is never mutated.
function withEnabled(state, id, on) {
    const next = parse(JSON.stringify(state));
    if (known(id)) next.enabled[id] = !!on;
    return next;
}

function withPlace(state, id, r, t) {
    const next = parse(JSON.stringify(state));
    if (known(id) && finite(r) && finite(t)) next.places[id] = {r: Math.round(r), t: Math.round(t)};
    return next;
}

function cleanedUp(state) {
    const next = parse(JSON.stringify(state));
    next.places = {};
    return next;
}

function hasPlaces(state) { return !!state && Object.keys(state.places || {}).length > 0; }
