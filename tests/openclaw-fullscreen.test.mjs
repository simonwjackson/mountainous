import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { brotliDecompressSync, gunzipSync } from 'node:zlib';
import { apply, check } from '../lib/openclaw-fullscreen.mjs';

const before = 'mcp-app-view[display-mode=fullscreen]{z-index:1000;background:var(--bg);box-sizing:border-box;border:0;flex-direction:column;height:100dvh;margin:0;padding-top:40px;display:flex;position:fixed;inset:0}';
const inline = 'mcp-app-view{width:100%;display:block}';
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'openclaw-fullscreen-'));
  t.after(() => rmSync(root, { recursive: true }));
  const assets = join(root, 'dist/control-ui/assets');
  mkdirSync(assets, { recursive: true });
  return { root, assets, css: join(assets, 'mcp-app-view-registration-test.css') };
}

test('only fullscreen changes and both encodings match the built CSS', t => {
  const { root, css } = fixture(t);
  writeFileSync(css, inline + before);
  assert.throws(() => check(root));
  apply(root);
  assert.equal(readFileSync(css, 'utf8'), inline + before.replace('display:flex;', 'display:flex!important;'));
  check(root);
  for (const [suffix, decode] of [['.gz', gunzipSync], ['.br', brotliDecompressSync]]) {
    assert.deepEqual(decode(readFileSync(css + suffix)), readFileSync(css));
    const saved = readFileSync(css + suffix);
    writeFileSync(css + suffix, 'outdated');
    assert.throws(() => check(root));
    writeFileSync(css + suffix, saved);
  }
  assert.throws(() => apply(root), /exactly once/);
});

for (const [label, content] of [['unknown', inline], ['duplicate', inline + before + before], ['changed', inline + before.replace('40px', '41px')]]) {
  test(`${label} selector fails before writing`, t => {
    const { root, css } = fixture(t);
    writeFileSync(css, content);
    assert.throws(() => apply(root), /exactly once/);
    assert.equal(readFileSync(css, 'utf8'), content);
  });
}

test('missing or multiple assets fail before writing', t => {
  const { root, assets, css } = fixture(t);
  assert.throws(() => apply(root), /exactly one/);
  writeFileSync(css, inline + before);
  writeFileSync(join(assets, 'mcp-app-view-registration-other.css'), inline + before);
  assert.throws(() => apply(root), /exactly one/);
  assert.equal(readFileSync(css, 'utf8'), inline + before);
});
