// A small MCP Apps host that frames the view the way OpenClaw does: a chat
// column with the card inline (its height follows the view), or the card filling
// the window in full screen. Query parameters:
//   drawing=<key in drawings.json>   mode=inline|fullscreen   theme=light|dark
//   delay=<ms>  fail=<tool>  hydrate=stuck    (the view's own calls, see fake-scryer.mjs)
//   blocked=1   the host refuses the view's tool calls, as OpenClaw's session policy did
//   hold=1      the model's tool call never finishes (the card's loading state)
//   error=1     the model's tool call fails
//   press=<css> after load, click this element in the view (to show a pending state)
//   nofull=1    a host without a full view
//   still=1     freeze spinners (for repeatable screenshots)
//   openclaw=1  size the inline frame as OpenClaw 2026.11.3 does: start at 160 px,
//               report that height as containerDimensions.height, grow to what the card reports (max 1200),
//               and leave a granted full screen at the 150 px iframe default (its full-screen fault)
import { AppBridge, PostMessageTransport } from "@modelcontextprotocol/ext-apps/app-bridge";
import { createFake } from "./fake-scryer.mjs";
import drawings from "./drawings.json";

const q = new URLSearchParams(location.search);
const frame = document.getElementById("frame");
const seen = document.getElementById("seen");
let mode = q.get("mode") === "fullscreen" ? "fullscreen" : "inline";
const knobs = Object.fromEntries(["delay", "fail", "hydrate", "home", "as"].filter((k) => q.has(k)).map((k) => [k, q.get(k)]));
if (q.get("theme")) document.documentElement.style.colorScheme = q.get("theme");

// The fake claw-scryer runs in this page, so the harness is static files.
const fake = createFake();
async function mcp(method, params, fromApp = false) {
  if (method === "resources/read") return { contents: [{ uri: params.uri, mimeType: "text/html;profile=mcp-app", text: await (await fetch("view.html")).text() }] };
  if (method === "tools/call") return fake.call(params.name, params.arguments, knobs, fromApp);
  throw new Error("Method not found");
}
const layout = () => { document.body.dataset.mode = mode; };

const drawing = drawings[q.get("drawing") ?? "search-office"];
document.getElementById("ask").textContent = drawing.ask;
document.getElementById("say").textContent = drawing.say;
const { contents } = await mcp("resources/read", { uri: "ui://scryer/media.html" });

layout();
const context = () => ({
  platform: "web",
  displayMode: mode,
  availableDisplayModes: q.get("nofull") ? ["inline"] : ["inline", "fullscreen"],
  // Inline, OpenClaw sizes the frame to the view's content: no fixed height.
  containerDimensions: mode === "fullscreen" || q.get("openclaw") ? { width: frame.clientWidth, height: frame.clientHeight } : { width: frame.clientWidth },
  safeAreaInsets: { top: 0, right: 0, bottom: 0, left: 0 },
  theme: q.get("theme") === "dark" ? "dark" : "light",
});
const bridge = new AppBridge(null, { name: "Harness", version: "1.0.0" }, { serverTools: {}, updateModelContext: { text: {} } }, { hostContext: context() });
bridge.oncalltool = async ({ name, arguments: args }) => {
  if (q.get("blocked")) throw new Error("The session's current tool policy does not allow this operation");
  return mcp("tools/call", { name, arguments: args }, true);
};
bridge.onupdatemodelcontext = async ({ content }) => { seen.textContent = content?.map((c) => c.text).join("\n") ?? ""; return {}; };
bridge.onrequestdisplaymode = async ({ mode: m }) => {
  mode = m === "fullscreen" ? "fullscreen" : "inline";
  layout();
  if (q.get("openclaw")) frame.style.setProperty("height", mode === "fullscreen" ? "150px" : "160px", "important");
  requestAnimationFrame(() => bridge.sendHostContextChange(context()));
  return { mode };
};
let frozen = false; // still=1: after settling, a screenshot tool's own resizes change nothing
bridge.onsizechange = ({ height }) => {
  if (frozen || mode !== "inline" || !height) return;
  frame.style.height = `${q.get("openclaw") ? Math.min(1200, Math.max(160, Math.round(height))) : Math.ceil(height)}px`;
  if (q.get("openclaw")) bridge.sendHostContextChange(context());
};
if (q.get("openclaw")) frame.style.height = "160px";
const initialized = new Promise((resolve) => { bridge.oninitialized = resolve; });
await bridge.connect(new PostMessageTransport(frame.contentWindow, frame.contentWindow));
frame.srcdoc = contents[0].text;
await initialized;
await bridge.sendToolInput({ arguments: drawing.input });
if (q.get("error")) await bridge.sendToolResult({ isError: true, content: [{ type: "text", text: JSON.stringify({ kind: "http", status: 503, message: "Scryer returned HTTP 503: TEMPORARY_UNAVAILABLE, retry after 30 seconds" }) }] });
else if (!q.get("hold")) await bridge.sendToolResult(await mcp("tools/call", { name: drawing.tool, arguments: drawing.input }));
const watchSize = new ResizeObserver(() => { if (!frozen) bridge.sendHostContextChange(context()); });
watchSize.observe(frame);
document.getElementById("close").addEventListener("click", () => { mode = "inline"; layout(); bridge.sendHostContextChange(context()); });

async function press(selector) {
  const doc = frame.contentDocument;
  for (let i = 0; i < 100; i++) {
    const el = doc?.querySelector(selector);
    if (el && !el.disabled) { el.click(); return; }
    await new Promise((r) => setTimeout(r, 50));
  }
}
if (q.get("press")) for (const sel of q.get("press").split("|")) await press(sel);
// Settled: no redraw for 400 ms. Then let the settle image load.
await new Promise((resolve) => {
  let timer = setTimeout(resolve, 400);
  const again = () => { clearTimeout(timer); timer = setTimeout(resolve, 400); };
  new MutationObserver(again).observe(frame.contentDocument.body, { subtree: true, childList: true, attributes: true, characterData: true });
  new MutationObserver(again).observe(frame, { attributes: true }); // the frame's own height
});
if (q.get("still")) { frozen = true; watchSize.disconnect(); frame.style.width = `${frame.clientWidth}px`; frame.style.setProperty("height", `${frame.clientHeight}px`, "important"); }
if (q.get("still")) document.querySelector("details").hidden = true; // its text changes as the card reports context
if (q.get("still")) frame.contentDocument.head.insertAdjacentHTML("beforeend", "<style>*,*::before,*::after{animation:none!important;transition:none!important}</style>");
document.body.dataset.ready = "1";
const settle = document.getElementById("settle");
settle.style.display = ""; settle.style.position = "absolute"; settle.style.width = settle.style.height = "1px"; settle.loading = "eager";
