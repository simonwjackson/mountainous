#!/usr/bin/env node
// Builds the static harness into harness/out/ (index.html, host.js, view.html)
// and, unless --build-only, serves it on 127.0.0.1:${PORT:-3177}. The fake
// claw-scryer runs inside the page (fake-scryer.mjs); nothing talks to Scryer.
import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { build } from "esbuild";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = process.env.OUT ?? path.join(HERE, "out");
mkdirSync(OUT, { recursive: true });
await build({ entryPoints: [path.join(HERE, "host.js")], bundle: true, format: "esm", outfile: path.join(OUT, "host.js"), target: "es2022", logLevel: "warning" });
copyFileSync(path.join(HERE, "..", "dist", "media.html"), path.join(OUT, "view.html"));
writeFileSync(path.join(OUT, "index.html"), readFileSync(path.join(HERE, "index.html")));
console.log(`built ${OUT}`);
if (process.argv.includes("--build-only")) process.exit(0);

const PORT = Number(process.env.PORT ?? 3177);
const TYPES = { ".html": "text/html", ".js": "text/javascript" };
createServer((req, res) => {
  const name = new URL(req.url, "http://x").pathname.replace(/^\/$/, "/index.html").slice(1);
  if (!["index.html", "host.js", "view.html"].includes(name)) return res.writeHead(404).end();
  res.writeHead(200, { "content-type": TYPES[path.extname(name)] }).end(readFileSync(path.join(OUT, name)));
}).listen(PORT, "127.0.0.1", () => console.log(`harness http://127.0.0.1:${PORT}/?drawing=search-office`));
