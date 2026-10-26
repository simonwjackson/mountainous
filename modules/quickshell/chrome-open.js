.pragma library

// One latest request per captured screen. The requested theme tags each
// request so a still-active old Desktop cannot consume its replacement's open.
function enqueue(pending, screen, theme, control) {
    const next = Object.assign({}, pending);
    next[screen] = {theme: theme, control: control};
    return next;
}

function take(pending, screen, theme, ready) {
    const request = pending[screen];
    if (!ready || !request || request.theme !== theme) return {pending: pending, request: null};
    const next = Object.assign({}, pending);
    delete next[screen];
    return {pending: next, request: request};
}
