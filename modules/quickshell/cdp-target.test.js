const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const dir = process.argv[2] || __dirname;
const qml = fs.readFileSync(path.join(dir, "CdpBrowser.qml"), "utf8");
const policy = {};
const policyFile = path.join(dir, "cdp-target.js");
if (fs.existsSync(policyFile)) vm.runInNewContext(fs.readFileSync(policyFile, "utf8").replace(/^\.pragma library\s*$/m, ""), policy);
const root = {pages: [], navigationHistory: {}, hostOfAppId: id => /^chrome-(.+?)__-/.exec(id || "")?.[1] || ""};
const scope = {root, CdpTarget: policy};
vm.runInNewContext(qml.slice(qml.indexOf("function targetFor("), qml.indexOf("function isBrowserWindow(")), scope);
const window = (host, title) => ({wayland: {appId: `chrome-${host}__-Default`}, title});
const page = (id, host, title) => ({id, host, title, url: `https://${host}/`, ws: `ws://${id}`});
root.pages = [page("a", "beta.test", "Alpha"), page("b", "other.test", "Other")];
assert.equal(scope.targetFor(window("alpha.test", "Alpha"))?.id, "a", "second navigation reuses the page after its host changed");
root.pages.push(page("c", "alpha.test", "Different"));
assert.equal(scope.targetFor(window("alpha.test", "Alpha"))?.id, "c", "exact host wins before title fallback");
root.pages = [page("a", "beta.test", "Shared"), page("b", "other.test", "Shared")];
assert.equal(scope.targetFor(window("alpha.test", "Shared")), null, "ambiguous titles never choose array order");
root.navigationHistory = {a: ["https://alpha.test/", "https://beta.test/"]};
assert.equal(scope.targetFor(window("alpha.test", "Shared"))?.id, "a", "a unique original host in URL history breaks a title tie");
root.navigationHistory.b = ["https://alpha.test/"];
assert.equal(scope.targetFor(window("alpha.test", "Shared")), null, "ambiguous title and history fail closed");
assert.equal(scope.targetFor(window("", "Shared")), null, "non-browser windows do not match titles");
assert.equal(scope.targetFor(null), null);
root.pages = [page("a", "alpha.test", "Shared"), page("b", "alpha.test", "Shared")];
assert.equal(scope.targetFor(window("alpha.test", "Shared")), null, "same-host title ties also fail closed");
root.pages = [page("a", "alpha.test", "Alpha"), page("b", "beta.test", "Beta")];
assert.equal(scope.targetFor({wayland: {appId: "chromium-browser"}, title: "Alpha - Chromium"})?.id, "a", "normal Chromium's active title selects its page");
root.pages.push(page("c", "gamma.test", "Alpha"));
assert.equal(scope.targetFor({wayland: {appId: "chromium-browser"}, title: "Alpha - Chromium"}), null, "normal windows with duplicate titles fail closed");
assert.equal(scope.targetFor({wayland: {appId: "ghostty"}, title: "Beta"}), null, "a non-browser cannot claim another application's title");
assert.equal(scope.targetFor({wayland: {appId: "chrome-ahmfndipfijlijminhiobipfjpafbndb-Default"}, title: "Beta"})?.id, "b", "an installed PWA can navigate in its original profile without losing its security frame");
root.pages = [{...page("web", "alpha.test", "Alpha"), endpoint:"web"}, {...page("normal", "alpha.test", "Alpha"), endpoint:"normal"}];
assert.equal(scope.targetFor({wayland:{appId:"chromium-browser"},title:"Alpha - Chromium"})?.id, "normal", "normal Chromium cannot navigate a same-title page in the separate web-app root");


// Actual /json/list titles and native titles from the Tab-less survey.
const realTitles = [
    ["nixos.org", "Nix &amp; NixOS | Reproducible builds and deployments", "Nix & NixOS | Reproducible builds and deployments"],
    ["nixos.org", "Download | Nix &amp; NixOS", "Download | Nix & NixOS"],
    ["github.com", "GitHub - NixOS/nixpkgs: Nix Packages collection &amp; NixOS · GitHub", "GitHub - NixOS/nixpkgs: Nix Packages collection & NixOS · GitHub"]
];
const entityTitles = [
    ...realTitles,
    ["entities.test", "Named &amp; &lt; &gt; &quot; &#39; &apos; &nbsp;", "Named & < > \" ' ' \u00a0"],
    ["entities.test", "Decimal &#38; &#60; &#62; &#34; &#39; &#160; &#128640;", "Decimal & < > \" ' \u00a0 🚀"],
    ["entities.test", "Hex &#x26; &#X3c; &#x3E; &#x22; &#x27; &#xa0; &#x1f680;", "Hex & < > \" ' \u00a0 🚀"],
    // A real document.title containing literal &amp; comes back as &amp;amp;
    // from /json/list. Decode once, and never decode the native title.
    ["entities.test", "Literal &amp;amp; &amp;#39; &amp;#x26;", "Literal &amp; &#39; &#x26;"],
    ["entities.test", "Unknown &unknown; incomplete &amp invalid &#0; &#x110000; &#xD800;", "Unknown &unknown; incomplete &amp invalid &#0; &#x110000; &#xD800;"]
];
for (const [host, encoded, native] of entityTitles) {
    for (const appId of ["chromium-browser", "chromium", "chrome-ahmfndipfijlijminhiobipfjpafbndb-Default", "chrome-original.test__-Default"]) {
        const endpoint = appId === "chrome-original.test__-Default" ? "web" : "normal";
        root.navigationHistory = {};
        root.pages = [{...page("encoded", host, encoded), endpoint}, {...page("other", "other.test", "Other"), endpoint}];
        const title = /^(chromium|chromium-browser)$/.test(appId) ? native + " - Chromium" : native;
        assert.equal(scope.targetFor({wayland: {appId}, title})?.id, "encoded", `${appId} matches the decoded CDP title: ${native}`);
        assert.equal(root.pages[0].title, encoded, "matching does not mutate the CDP title");
        root.pages.push({...page("duplicate", "duplicate.test", native.replace(/&/g, "&#38;")), endpoint});
        assert.equal(scope.targetFor({wayland: {appId}, title}), null, `${appId} refuses duplicate titles after decoding: ${native}`);
    }
}
root.pages = [page("literal", "entities.test", "Literal &amp;amp;")];
assert.equal(scope.targetFor({wayland: {appId: "chromium-browser"}, title: "Literal & - Chromium"}), null,
    "a literal entity must not be decoded twice into another window's title");
root.pages = [page("encoded", "original.test", "A &amp; B"), page("decoded", "original.test", "A & B")];
assert.equal(scope.targetFor(window("original.test", "A & B")), null, "same-host duplicates after decoding also fail closed");

// With no endpoint, the preview harness's explicit page fixture stays intact.
vm.runInNewContext(qml.slice(qml.indexOf("function publishPages("), qml.indexOf("// ACTIVE WINDOW")), scope);
root.endpointPages = {};
const fixturePages = root.pages;
scope.refreshEndpoint("normal",0);
assert.equal(root.pages,fixturePages);
root.publishPages = scope.publishPages;
root.publishPages("normal",[{id:"previous-browser-page"}]);
scope.refreshEndpoint("normal",0);
assert.equal(root.pages.length,0,"a previously live endpoint is cleared when its port vanishes");
root.pages = [
    {...page("web-root", "beta.test", "Alpha"), endpoint:"web"},
    {...page("normal-root", "alpha.test", "Different"), endpoint:"normal"}
];
assert.equal(scope.targetFor(window("alpha.test","Alpha"))?.id,"web-root",
    "a declared web app must not navigate the normal-profile target with its original host");
// A peer disconnect must release the navigation gate so a restarted browser
// can accept the next address. Intentional socket resets must not cancel it.
const statusBody = qml.match(/onStatusChanged:\s*function\(status\)\s*({[\s\S]*?})\s*onTextMessageReceived:/)[1];
const socket = {active:true,sendTextMessage() {}};
const events = {Open:1,Error:2,Closed:3};
root.log = () => {};
const statusChanged = vm.runInNewContext("(function(status)"+statusBody+")",{root,pageSock:socket,WebSocket:events});
root.pendingNav = {id:"closed-target",url:"https://example.net/"};
statusChanged(events.Closed);
assert.equal(root.pendingNav,null,"peer closure releases an in-flight navigation");
root.pendingNav = {id:"next-target",url:"https://example.net/"};
socket.active = false;
statusChanged(events.Closed);
assert.equal(root.pendingNav.id,"next-target","intentional reset does not cancel a new request");

console.log("cdp-target: window matching, single-pass HTML entities, profile separation, ambiguous titles, previews and disconnect recovery pass");
