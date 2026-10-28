.pragma library
// Which icon-theme name an app's window or desktop entry draws, for both
// themes (docs/plans/desktop-themes/small-fixes.md). Pure, so
// app-icon.test.js runs it.
//
// A window class is not always an icon name, and Chromium's are the cases
// that matter: the browser's class is chromium-browser (or chromium); an
// --app web app's is chrome-<host>__-Default; an installed PWA's is
// chrome-<app id>-Default. The desktop art package (scripts/generate-
// desktop-art.py) draws each theme's browser icon under "chromium" and a
// lettermark for each web app under its class, so these names reach the
// Phase 4 icons and never Chromium's own logo.

var BROWSER = "chromium";
var GENERIC = "application-x-executable";

function isBrowser(appId) {
    var id = String(appId || "").toLowerCase();
    return id === "chromium" || id === "chromium-browser";
}

// chrome-<host>__-Default (--app) or chrome-<32 letters a-p>-Default (an
// installed PWA). Only the Default profile: web-app and Myoko's Chromium
// use no other.
function isWebApp(appId) {
    return /^chrome-.+-Default$/.test(String(appId || ""));
}

// A desktop entry's Icon= may be a theme name or a file path. Chromium
// writes a PWA's own PNG as a path; a theme name can follow the theme.
function themable(icon) {
    var s = String(icon || "");
    return s !== "" && s.charAt(0) !== "/" && s.indexOf("://") < 0;
}

// The name for a browser or web-app class, else "". entryIcon: the Icon=
// of the app's desktop entry, if known. A declared web app's entry names
// its lettermark (webapp-<id>), which every theme and hicolor have; a PWA's
// entry names a file, so its class, which the art package draws.
function special(appId, entryIcon) {
    if (isBrowser(appId)) return BROWSER;
    if (isWebApp(appId)) return themable(entryIcon) ? String(entryIcon) : String(appId);
    return "";
}

// The icon-theme name for an app: the browser and web apps as above,
// otherwise its desktop entry's icon, otherwise its id.
function themeName(appId, entryIcon) {
    return special(appId, entryIcon) || String(entryIcon || "") || String(appId || "");
}

// The fallback for Quickshell.iconPath(name, fallback): a web app the art
// package does not know (an --app window of any other site, a newer PWA
// without its own hicolor icon) is still a browser window.
function fallback(name) {
    var s = String(name || "");
    return isWebApp(s) || s.indexOf("webapp-") === 0 ? BROWSER : GENERIC;
}
