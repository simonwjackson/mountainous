// Temporary dist fix: the chat renderer's inline display:block wins over
// fullscreen flex. Keep inline unchanged; reject unknown or patched bundles.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { brotliCompressSync, brotliDecompressSync, gzipSync, gunzipSync } from 'node:zlib';

const before = 'mcp-app-view[display-mode=fullscreen]{z-index:1000;background:var(--bg);box-sizing:border-box;border:0;flex-direction:column;height:100dvh;margin:0;padding-top:40px;display:flex;position:fixed;inset:0}';
const after = before.replace('display:flex;', 'display:flex!important;');
const inline = 'mcp-app-view{width:100%;display:block}';
function target(root) {
  const assets = join(root, 'dist/control-ui/assets');
  const names = readdirSync(assets).filter(name => /^mcp-app-view-registration-.*\.css$/.test(name));
  assert.equal(names.length, 1, 'expected exactly one MCP App stylesheet');
  return join(assets, names[0]);
}
function once(css, selector) {
  assert.equal(css.split(selector).length - 1, 1, 'selector must match exactly once; unknown or already patched build');
}
export function apply(root) {
  const file = target(root);
  const css = readFileSync(file, 'utf8');
  once(css, before);
  once(css, inline);
  assert.ok(!css.includes(after));
  const data = Buffer.from(css.replace(before, after));
  writeFileSync(file, data);
  writeFileSync(file + '.gz', gzipSync(data));
  writeFileSync(file + '.br', brotliCompressSync(data));
}
export function check(root) {
  const file = target(root);
  const data = readFileSync(file);
  const css = data.toString('utf8');
  once(css, after);
  once(css, inline);
  assert.ok(!css.includes(before), 'unpatched fullscreen selector');
  assert.deepEqual(gunzipSync(readFileSync(file + '.gz')), data, 'stale gzip asset');
  assert.deepEqual(brotliDecompressSync(readFileSync(file + '.br')), data, 'stale Brotli asset');
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [mode, root] = process.argv.slice(2);
  assert.ok(['apply', 'check'].includes(mode) && root, 'usage: openclaw-fullscreen.mjs apply|check ROOT');
  (mode === 'apply' ? apply : check)(root);
}
