#!/usr/bin/env node
// Builds dist/media.html: one self-contained page (script and styles inline),
// which media-tsnet-proxy embeds with go:embed. The page names the SHA-256 of its
// sources (sources.txt), and a Go test checks that stamp, so a source change
// without a rebuild fails `go test` without npm.
//
//   node build.mjs           write dist/media.html
//   node build.mjs --check   rebuild in memory; fail if the committed page differs
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { build } from "esbuild";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(ROOT, "dist", "media.html");
const at = (p) => path.join(ROOT, p);

/** The hashed inputs, one path per line. The Go test reads the same list. */
const sources = readFileSync(at("sources.txt"), "utf8").split("\n").map((l) => l.trim()).filter((l) => l && !l.startsWith("#"));

/** SHA-256 over each source as `path\nlength\n` then its bytes, in list order. */
function sourceHash() {
  const hash = createHash("sha256");
  for (const p of sources) {
    const bytes = readFileSync(at(p));
    hash.update(`${p}\n${bytes.length}\n`);
    hash.update(bytes);
  }
  return hash.digest("hex");
}

const bundle = await build({
  entryPoints: [at("src/app.js")],
  bundle: true,
  format: "iife",
  minify: true,
  target: "es2022",
  write: false,
  metafile: true,
  logLevel: "warning",
});
// Every bundled file of ours must be hashed, or the stamp could miss a change.
for (const input of Object.keys(bundle.metafile.inputs)) {
  const rel = path.relative(ROOT, path.resolve(process.cwd(), input));
  if (!rel.startsWith("node_modules") && !sources.includes(rel)) throw new Error(`${rel} is bundled but not listed in sources.txt`);
}
const js = bundle.outputFiles[0].text.replaceAll("</script", "<\\/script");
const css = readFileSync(at("src/media.css"), "utf8");
const html = readFileSync(at("src/media.html"), "utf8")
  .replace("<!DOCTYPE html>\n", `<!DOCTYPE html>\n<!-- scryer-media-view source-sha256:${sourceHash()} Built by scryer-view/build.mjs. Do not edit. -->\n`)
  .replace("<!--CSS-->", () => `<style>\n${css}</style>`)
  .replace("<!--JS-->", () => `<script>\n${js}</script>`);

if (process.argv.includes("--check")) {
  let committed = "";
  try { committed = readFileSync(OUT, "utf8"); } catch {}
  if (committed !== html) {
    console.error("dist/media.html is out of date. Run: node build.mjs");
    process.exit(1);
  }
  console.log(`dist/media.html matches its sources (${Buffer.byteLength(html)} bytes).`);
} else {
  writeFileSync(OUT, html);
  console.log(`wrote dist/media.html (${Buffer.byteLength(html)} bytes)`);
}
